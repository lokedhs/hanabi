defmodule Hanabi.Server do
  import Hanabi.Handler, only: [reply: 2]
  alias Hanabi.Registry
  alias Hanabi.User

  def accept(port \\ 6667) do
    GenEvent.start_link(name: Events)
    GenEvent.add_handler(Events, Hanabi.Handler, [])

    # Create the :users and :channels registries
    Registry.create(:users)
    Registry.create(:channels)

    case :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true]) do
      { :ok, socket } ->
        Task.async(fn -> loop_acceptor(socket) end)
        IO.puts "Hanabi is up and running ! Now accepting requests on port #{port}."
        Hanabi.Handler.handle_events
      { :error, :eaddrinuse } ->
        IO.puts "Address already in use ;("
        System.halt(1)
    end
  end

  defp loop_acceptor(socket) do
    { :ok, client } = :gen_tcp.accept(socket)
    pid = spawn fn -> initial_serve(client) end
    #:ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  # Handles initial connection handshake with USER + NICK messages
  defp initial_serve(client) do
    case :gen_tcp.recv(client, 0) do
      { :ok, data } ->
        user = case Registry.get(:users, client) do
          {:ok, user} -> user
          {:error, _} ->
            user = struct(User)
            Registry.set(:users, client, user)
            user
        end
        #Agent.update(Users, fn users -> Dict.put_new(users, client, %{ channels: [] }) end)
        data = String.strip(data) |> String.split(" ")
        case data do
          ["NICK" | nick] ->
            hostname = resolve_hostname(client)
            Registry.set(:users, client, struct(user,
                                                %{nick: List.to_string(nick),
                                                  hostname: hostname})
            )
          ["USER", username, _mode, _ | real_name_parts] ->
            Registry.set(:users, client,
                         struct(user, %{
                           username: username,
                           real_name:  Enum.join(real_name_parts, " ")}
                         )
            )
          other -> IO.inspect("Received unknown message: #{Enum.join(other, "")}")
        end

        {:ok, user} = Registry.get(:users, client)
        unless user.nick == nil || user.hostname == nil || user.username == nil do
            # User has connected and sent through NICK + USER messages.
            IO.inspect Registry.get(:users, client)
            welcome(client, user.nick)
            serve(client)
        else
            # User has not sent through all the right messages yet.
            # Keep listening!
            initial_serve(client)
        end

      { :error, :closed } ->
        IO.puts "Connection closed by client."
    end
  end

  defp serve(client) do
    case :gen_tcp.recv(client, 0) do
      { :ok, data } ->
        IO.puts "<- #{String.strip(data)}"
        String.strip(data) |> String.split(" ") |> dispatch(client)
        serve(client)
      { :error, :closed } ->
        IO.puts "Connection closed by client."
    end
  end

  defp dispatch([event | parts], client) do
    GenEvent.notify(Events, { event, parts, client })
  end

  defp resolve_hostname(client) do
    {:ok, {ip, _port}} = :inet.peername(client)
    case :inet.gethostbyaddr(ip) do
      { :ok, { :hostent, hostname, _, _, _, _}} ->
        hostname
      { :error, _error } ->
        IO.puts "Could not resolve hostname for #{ip}. Using IP instead."
        Enum.join(Tuple.to_list(ip), ".")
    end
  end

  defp welcome(client, nick) do
    reply(client, ":irc.localhost 001 #{nick} Welcome to Hanabi !")
    reply(client, ":irc.localhost 002 #{nick} Yeah, it's pretty empty.")
  end
end

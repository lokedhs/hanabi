defmodule Hanabi.IRC.Server do
  alias Hanabi.{User, IRC}
  alias Hanabi.IRC.Message
  require Logger
  use Hanabi.IRC.Numeric

  @moduledoc false
  @handler Hanabi.IRC.Handler
  @hostname Application.get_env(:hanabi, :hostname)
  @motd_file Application.get_env(:hanabi, :motd)

  # Start TCP socket
  def accept(port \\ 6667) do
    case :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true]) do
      { :ok, socket } ->
        Logger.info "Hanabi is up and running ! Port: #{port}"
        loop_acceptor(socket)
      { :error, :eaddrinuse } ->
        Logger.error "Address already in use."
        System.halt(1)
    end
  end

  # Accept clients
  defp loop_acceptor(socket) do
    { :ok, client } = :gen_tcp.accept(socket)
    pid = spawn fn -> initial_serve(client) end
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  # Handles initial connection handshake : PASS, USER, NICK messages
  defp initial_serve(client) do
    case :gen_tcp.recv(client, 0) do
      { :ok, data } ->
        user = case User.get(client) do
          nil -> User.set(client, struct(User, %{port: client, key: client}))
          user -> user
        end

        msg = IRC.parse(data)

        if msg do
          case msg.command do
            "PASS" -> :not_implemented # ignored
            "NICK" -> GenServer.call(@handler, {client, msg})
            "USER" -> GenServer.call(@handler, {client, msg})
            _ -> Logger.debug "Ignored command (initial serve) : #{msg.command}"
          end

          user = User.get(client) # user was most likely modified
          if IRC.validate(:user, user) do
            Logger.debug "New IRC user : #{User.ident_for(user)}"
            send_motd(user)
            serve(client)
          else
            # User has not sent through all the right messages yet.
            # Keep listening!
            initial_serve(client)
          end
        else
          Logger.warn "Received invalid message (ignored) : #{msg}"
          initial_serve(client)
        end

      { :error, :closed } ->
        Logger.debug "Connection closed by client."
        User.destroy(client)
    end
  end

  # Get new inputs
  defp serve(client) do
    case :gen_tcp.recv(client, 0) do
      { :ok, data } ->
        msg = IRC.parse(data)
        Kernel.send @handler, {client, msg}
        serve(client)
      { :error, :closed } ->
        Logger.debug "Connection closed by client."
    end
  end

###
# Misc

  defp send_motd(user) do
    if File.exists?(@motd_file) do
      lines = File.stream!(@motd_file) |> Stream.map(&String.trim/1)

      #RPL_MOTDSTART
      User.send user, %Message{
        prefix: @hostname,
        command: @rpl_motdstart,
        middle: user.nick,
        trailing: "- #{@hostname} Message of the day - "
      }

      #RPL_MOTD
      for line <- lines do
      User.send user, %Message{
          command: @rpl_motd,
          prefix: @hostname,
          middle: user.nick,
          trailing: "- " <> line
        }
      end

      #RPL_ENDOFMOTD
      User.send user, %Message{
        prefix: @hostname,
        command: @rpl_endofmotd,
        middle: user.nick,
        trailing: "End of /MOTD command"
      }
    else
      User.send user, %Message{
        prefix: @hostname,
        command: @err_nomotd,
        middle: user.nick,
        trailing: "MOTD File is missing"
      }
    end
  end
end

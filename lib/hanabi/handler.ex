defmodule Hanabi.Handler do
  alias Hanabi.User
  alias Hanabi.Channel
  alias Hanabi.Registry
  use GenEvent

  def handle_event({ event, parts, client }, messages) do
    { :ok, [{event, parts, client} | messages ]}
  end

  def handle_call(:messages, messages) do
    { :ok, messages, [] }
  end

  def handle_events do
    stream = GenEvent.stream(Events)
    for event <- stream do
      case event do
        { "PING", [name], client } ->
          handle_ping(client, name)
        { "NICK", [nick], client } ->
          handle_nick(client, nick)
        { "JOIN", [channel], client } ->
          handle_join(client, channel)
        _ ->
          IO.puts "Unhandled event!"
          IO.inspect(event)
      end
    end
  end

  #####################
  # Broadcast & reply

  def reply(client, msg) do
    IO.puts("-> #{msg}")
    :gen_tcp.send(client, "#{msg}\r\n")
  end

  def broadcast_for(user, msg) do
    # Boradcast on all channels containing the user
    :noop
  end

  def channel_broadcast(channel, msg) do
  end

  #################
  # Handling stuff

  defp handle_nick(client, nick) do
    user = Registry.get :users, client
    # Need to set ident here, as the reply needs to contain old nick
    ident = user |> User.ident_for
    Registry.set :users, client, struct(user, %{nick: nick})
    msg = "#{ident} NICK #{nick}"
    broadcast_for(user, msg)
  end

  defp handle_ping(client, name) do
    reply(client, "PONG #{name}")
  end

  defp handle_join(client, channel_name) do
    {:ok, user} = Registry.get :users, client
    ident = User.ident_for(user)

    # Attempt to create the channel if it doesn't exist already.
    channel = case Registry.get(:channels, channel_name) do
          {:ok, channel} -> channel
          {:error, _} ->
            channel = struct(Channel)
            Registry.set(:channels, channel_name, channel)
            channel
        end

    # User has joined channel, so add them to the list.
    channel = struct(channel, %{users: channel.users ++ [user.nick]})
    Registry.set :channels, channel_name, channel

    # Add this channel to the list of channels for the user
    Registry.set :users, client, struct(user, %{channels: user.channels ++ [channel_name]})

    channel_broadcast(channel, "#{ident} JOIN #{channel_name}")

    # Show the topic
    reply(client, ":irc.localhost 332 #{user.nick} #{channel_name} :topic !")
    # And a list of names
    names = channel.users |> Enum.join(" ")
    reply(client, ":irc.localhost 353 #{user.nick} = #{channel_name} :#{names}")
    reply(client, ":irc.localhost 366 #{user.nick} #{channel_name} :End of /NAMES list.")
  end
end

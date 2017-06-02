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
        { "PART", [channel | part_message], client } ->
          handle_part(client, channel, part_message)
        { "WHO", [channel], client } ->
          handle_who(client, channel)
        { "PRIVMSG", [channel | parts ], client } ->
          handle_privmsg(client, channel, parts)
        { "QUIT", parts, client } ->
          handle_quit(client, ["QUIT" | parts])
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

  def broadcast(users, msg) do
    Enum.each users, fn(user) ->
      case user do
        {:irc, _, client} -> reply client, msg
        _ -> :noop
      end
    end
  end

  #################
  # Handling stuff

  defp handle_nick(client, nick) do
    {:ok, user} = Registry.get :users, client
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
    channel = struct(channel, %{users: channel.users ++ [{:irc, user.nick, client}]})
    Registry.set :channels, channel_name, channel

    # Add this channel to the list of channels for the user
    Registry.set :users, client, struct(user, %{channels: user.channels ++ [channel_name]})

    broadcast(channel.users, "#{ident} JOIN #{channel_name}")

    # Send the topic to the new client
    # RPL_TOPIC 332
    reply(client, ":irc.localhost 332 #{user.nick} #{channel_name} :topic !")

    # And a list of names
    # RPL_NAMREPLY 353
    names = Enum.map(channel.users, fn({_,nick,_}) -> nick end) |> Enum.join(" ")
    reply(client, ":irc.localhost 353 #{user.nick} = #{channel_name} :#{names}")
    #reply(client, ":irc.localhost 366 #{user.nick} #{channel_name} :End of /NAMES list.")
  end

  defp handle_part(client, channel_name, part_message) do
    {:ok, user} = Registry.get :users, client
    {:ok, channel} = Registry.get :channels, channel_name
    ident = User.ident_for(user)

    part_message = Enum.join(part_message, " ")
    broadcast(channel.users, "#{ident} PART #{channel_name} #{part_message}")

    # User has left the channel, so delete them from list.
    Registry.set :users, client, struct(user, %{channels: List.delete(user.channels, channel_name)})
    names = Enum.reject(channel.users, fn ({_, nick, _}) -> nick == user.nick end)
    unless Enum.empty?(names) do
      Registry.set :channels, channel_name, struct(channel,%{users: names})
    else
      Registry.drop :channels, channel_name
    end
  end

  defp handle_privmsg(client, channel_name, parts) do
    {:ok, user} = Registry.get :users, client
    {:ok, channel} = Registry.get :channels, channel_name
    ident = User.ident_for(user)

    message = Enum.join(parts, " ")
    IO.inspect channel.users
    IO.inspect user.nick
    case Enum.any?(channel.users, fn ({_, _, conn}) -> conn == client end) do
      true ->
        IO.inspect channel.users
        IO.inspect user.nick
        users = Enum.reject(channel.users, fn ({_, _, conn}) -> conn == client end)
        broadcast(users, "#{ident} PRIVMSG #{channel_name} #{message}")
      false ->
      reply(client, ":irc.localhost 404 #{user.nick} #{channel_name} :Cannot send to channel")
    end
  end

  defp handle_who(_socket, _channel) do
    # @TODO
  end

  defp handle_quit(client, parts) do
    {:ok, user} = Registry.get :users, client
    ident = User.ident_for(user)

    msg = "#{ident} #{Enum.join(parts, " ")}"
    broadcast_for(user, msg)

    Enum.each user.channels, fn(channel) ->
      # Remove NICK from CHANNEL
    end

    # Destroy user
    Registry.drop :users, client

    # Close connection.
    :gen_tcp.close(client)
  end
end

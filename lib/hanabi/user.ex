defmodule Hanabi.User do
  alias Hanabi.{Registry, IRC, Channel}

  defstruct nick: nil,
    username: nil,
    realname: nil,
    hostname: nil,
    type: :irc,
    channels: []

  def ident_for(user) do
    username = String.slice(user.username, 0..7)
    ":#{user.nick}!~#{username}@#{user.hostname}"
  end

  def get_all(), do: Registry.dump(:users)
  def get_by_nick(nick) do
    Enum.find(get_all(), fn([{_,user}]) -> user.nick == nick end)
  end

  def set_nick(client, user, nick) do
    # Need to set ident here, as the reply needs to contain old nick
    ident = user |> ident_for
    Registry.set :users, client, struct(user, %{nick: nick})
    msg = "#{ident} NICK #{nick}"
    IRC.broadcast_for(user, msg)
  end

  def privmsg(client, dst, msg) do
    {:ok, user} = Registry.get :users, client
    ident = ident_for(user)
    lookup = get_by_nick(dst)

    unless lookup == nil do
      [{port_or_pid, client}] = lookup
      case client.type do
        :irc -> IRC.send(port_or_pid, "#{ident} PRIVMSG #{dst} #{msg}")
        :bridge -> Kernel.send(port_or_pid, %{privmsg: msg, sender: user})
      end
    else
      # 401 ERR_NOSUCHNICK
      IRC.reply(client, 401, "#{user.nick} #{dst} :No such nick/channel")
    end

  end

  def join_channel(client, channel_name) do
    {:ok, user} = Registry.get :users, client
    ident = ident_for(user)

    # Create the channel if it doesn't exist already.
    channel = case Registry.get(:channels, channel_name) do
          {:ok, channel} -> channel
          {:error, _} ->
            channel = struct(Channel)
            Registry.set(:channels, channel_name, channel)
            channel
        end

    # Add the user to the channel's members
    channel = struct(channel, %{users: channel.users ++ [{:irc, user.nick, client}]})
    Registry.set :channels, channel_name, channel

    # Add this channel to the list of channels for the user
    Registry.set :users, client, struct(user, %{channels: user.channels ++ [channel_name]})
    IRC.broadcast(channel.users, "#{ident} JOIN #{channel_name}")

    # Send the channel's topic to the new client (332 RPL_TOPIC)
    IRC.reply(client, 332, "#{user.nick} #{channel_name} :#{channel.topic}")

    # Send the list of the members to the new client (353 RPL_NAMREPLY)
    names = Enum.map(channel.users, fn({_,nick,_}) -> nick end) |> Enum.join(" ")
    IRC.reply(client, 353, "#{user.nick} = #{channel_name} :#{names}")
  end

  def part_channel(client, channel_name, part_message) do
    {:ok, user} = Registry.get :users, client
    {:ok, channel} = Registry.get :channels, channel_name
    ident = ident_for(user)

    # Broadcast PART message
    IRC.broadcast(channel.users, "#{ident} PART #{channel_name} #{part_message}")

    # Remove the channel from the user's list.
    Registry.set(:users, client, struct(
      user, %{channels: List.delete(user.channels, channel_name)})
    )

    # User has left the channel, so delete it from channel's members.
    names = Enum.reject(channel.users, fn ({_, nick, _}) -> nick == user.nick end)
    unless Enum.empty?(names) do
      Registry.set :channels, channel_name, struct(channel,%{users: names})
    else
      Registry.drop :channels, channel_name
    end
  end

  def quit(client, part_message) do
    {:ok, user} = Registry.get :users, client

    # Broadcast part message
    IRC.broadcast_for(user, part_message)

    Enum.each user.channels, fn(_channel) ->
      :noop  # Remove NICK from CHANNEL
    end

    # Destroy user
    Registry.drop :users, client

    # Close connection.
    :gen_tcp.close(client)
  end
end

defmodule Hanabi.User do
  alias Hanabi.{Registry, Dispatch, User, Channel}

  @moduledoc false
  @table :users # ETS table, see Hanabi.Registry

  defstruct nick: nil,
    username: nil,
    realname: nil,
    hostname: nil,
    type: :irc,
    port_or_pid: nil,
    channels: []


  ####
  # Registry access

  def get(key), do: Registry.get @table, key

  def get_all(), do: Registry.dump(@table)

  def get_by_nick(nick) do
    result = Enum.find(get_all(), fn([{_,user}]) -> user.nick == nick end)
    if result, do: {:ok, List.first(result)}, else: {:error, :not_found}
  end

  def update(key, value) do
    {:ok, user} = User.get(key)
    Registry.set @table, key, struct(user, value)
  end

  def set(key, value), do: Registry.set :users, key, value

  def drop(key), do: Registry.drop @table, key

  ###

  def ident_for(user) do
    username = String.slice(user.username, 0..7)
    ":#{user.nick}!~#{username}@#{user.hostname}"
  end

  def set_nick(client, user, nick) do
    # Need to set ident here, as the reply needs to contain old nick
    ident = user |> ident_for
    User.set(client, struct(user, %{nick: nick}))

    msg = "#{ident} NICK #{nick}"
    Dispatch.send client, msg
    Dispatch.broadcast_for(client, msg)
  end

  def privmsg(client, dst, msg) do
    {:ok, user} = User.get(client)
    ident = ident_for(user)
    {status, lookup} = get_by_nick(dst)

    unless status == :error do
      {_key, dst_user} = lookup
      Dispatch.send(dst_user.port_or_pid, "#{ident} PRIVMSG #{dst} #{msg}", client)
    else
      # 401 ERR_NOSUCHNICK
      Dispatch.reply(client, 401, "#{user.nick} #{dst} :No such nick/channel")
    end

  end

  def join_channel(client, channel_name) do
    {:ok, user} = User.get client
    ident = ident_for(user)

    # Create the channel if it doesn't exist already.
    channel = case Channel.get(channel_name) do
          {:ok, channel} -> channel
          {:error, _} ->
            channel = struct(Channel)
            Channel.set(channel_name, channel)
            channel
        end

    # Add the user to the channel's members
    channel = struct(channel, %{users: channel.users ++ [{:irc, user.nick, client}]})

    # Add the user to the channel
    Channel.set(channel_name, channel)

    # Add this channel to the list of channels for the user
    User.set(client, struct(user, %{channels: user.channels ++ [channel_name]}))
    Dispatch.broadcast(channel.users, "#{ident} JOIN #{channel_name}")

    # Send the channel's topic to the new client (332 RPL_TOPIC)
    Dispatch.reply(client, 332, "#{user.nick} #{channel_name} :#{channel.topic}")

    # Send the list of the members to the new client (353 RPL_NAMREPLY)
    names = Enum.map(channel.users, fn({_,nick,_}) -> nick end) |> Enum.join(" ")
    Dispatch.reply(client, 353, "#{user.nick} = #{channel_name} :#{names}")
  end

  def part_channel(client, channel_name, part_message) do
    {:ok, user} = User.get(client)
    {:ok, channel} = Channel.get(channel_name)
    ident = ident_for(user)

    # Broadcast PART message
    Dispatch.broadcast(channel.users, "#{ident} PART #{channel_name} #{part_message}")

    # Remove the channel from the user's list.
    User.set(client, struct(
      user, %{channels: List.delete(user.channels, channel_name)})
    )

    # User has left the channel, so delete it from channel's members.
    names = Enum.reject(channel.users, fn ({_, nick, _}) -> nick == user.nick end)
    unless Enum.empty?(names) do
      Channel.set(channel_name, struct(channel,%{users: names}))
    else
      Channel.drop(channel_name)
    end
  end

  def quit(client, part_message) do
    {:ok, user} = User.get(client)

    # Broadcast part message
    Dispatch.broadcast_for(client, part_message)

    Enum.each user.channels, fn(channel) ->
      part_channel(client, channel, part_message)
    end

    # Destroy user
    User.drop(client)

    # Close connection.
    :gen_tcp.close(client)
  end

  def is_nick_in_use?(nick) do
    case get_by_nick(nick) do
      {:ok, _} -> true
      _ -> false
    end
  end
end

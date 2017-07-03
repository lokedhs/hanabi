defmodule Hanabi.Channel do
  alias Hanabi.{Dispatch, User, Channel, Registry}

  @moduledoc false
  @table :channels # ETS table, see Hanabi.Registry

  defstruct users: [], topic: "topic"

  ####
  # Registry access

  def get(key), do: Registry.get @table, key

  def get_all(), do: Registry.dump @table

  def update(key, value) do
    {:ok, user} = Channel.get(key)
    Registry.set @table, key, struct(user, value)
  end

  def set(key, value), do: Registry.set @table, key, value

  def drop(key), do: Registry.drop @table, key

  ###

  def set_topic(channel_name, user, topic) do
    {:ok, channel} = Channel.get(channel_name)
    Channel.set(channel_name, struct(channel, topic: topic))
 
    # 332 RPL_TOPIC
    hostname = Application.get_env(:hanabi, :hostname)
    msg = if user do
      ":#{hostname} 332 #{user.nick} #{channel_name} #{topic}"
    else
      ":#{hostname} 332 #{channel_name} #{topic}"
    end
    Dispatch.broadcast(channel.users, msg)
  end

  def add_user(channel_name, user) do
    {:ok, channel} = Channel.get(channel_name)
    channel = struct(channel, %{users: channel.users
              ++ [{user.type, user.nick, user.port_or_pid}]})
    Channel.set(channel_name, channel)
    Dispatch.broadcast(channel.users, "#{User.ident_for(user)} JOIN #{channel_name}")
  end

  def remove_user(channel_name, user, part_msg \\ "") do
    {:ok, channel} = Channel.get(channel_name)
    Dispatch.broadcast(channel.users, "#{User.ident_for(user)} PART #{channel_name} #{part_msg}")

    names = Enum.reject(channel.users, fn ({_, nick, _}) -> nick == user.nick end)
    unless Enum.empty?(names) do
      Channel.set(channel_name, struct(channel, users: names))
    else
      Channel.drop(channel_name)
    end
  end

  def privmsg(client, channel_name, msg) do
    {:ok, channel} = Channel.get(channel_name)
    {:ok, user} = User.get(client)
    ident = User.ident_for(user)

    case Enum.any?(channel.users, fn ({_, _, conn}) -> conn == client end) do
      true ->
        users = Enum.reject(channel.users, fn ({_, _, conn}) -> conn == client end)
        Dispatch.broadcast(users, "#{ident} PRIVMSG #{channel_name} #{msg}", client)
      false ->
        # 404 ERR_CANNOTSENDTOCHAN
        Dispatch.reply(client, "404", "#{user.nick} #{channel_name} :Cannot send to channel")
    end
  end
end

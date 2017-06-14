defmodule Hanabi.Channel do
  alias Hanabi.{IRC, Registry, User}

  @moduledoc false

  defstruct users: [], topic: "topic"

  def set_topic(channel_name, user, topic) do
    {:ok, channel} = Registry.get(:channels, channel_name)
    Registry.set :channels, channel_name, struct(channel, %{topic: topic})
 
    # 332 RPL_TOPIC
    hostname = Application.get_env :hanabi, :hostname
    msg = if user do
      ":#{hostname} 332 #{user.nick} #{channel_name} #{topic}"
    else
      ":#{hostname} 332 #{channel_name} #{topic}"
    end
    IRC.broadcast(channel.users, msg)
  end

  def add_user(channel_name, user) do
    channel = Registry.get :channels, channel_name
    channel = struct(channel, %{users: channel.users ++ [user]})
    Registry.set :channels, channel_name, channel
    {_, nick, _} = user 
    IRC.broadcast(channel.users, "#{nick} JOIN #{channel_name}")
  end

  def remove_user(channel_name, user, part_msg) do
    channel = Registry.get :channels, channel_name
    {_, user_nick, _} = user 
    IRC.broadcast(channel.users, "#{user_nick} PART #{channel_name} #{part_msg}")

    names = Enum.reject(channel.users, fn ({_, nick, _}) -> nick == user_nick end)
    unless Enum.empty?(names) do
      Registry.set :channels, channel_name, struct(channel,%{users: names})
    else
      Registry.drop :channels, channel_name
    end
  end

  def privmsg(client, channel_name, msg) do
    {:ok, channel} = Registry.get :channels, channel_name
    {:ok, user} = Registry.get :users, client
    ident = User.ident_for(user)

    case Enum.any?(channel.users, fn ({_, _, conn}) -> conn == client end) do
      true ->
        users = Enum.reject(channel.users, fn ({_, _, conn}) -> conn == client end)
        IRC.broadcast(users, "#{ident} PRIVMSG #{channel_name} #{msg}")
      false ->
        # 404 ERR_CANNOTSENDTOCHAN
        IRC.reply(client, "404", "#{user.nick} #{channel_name} :Cannot send to channel")
    end
  end
end

defmodule Hanabi.Channel do
  alias Hanabi.{IRC, Registry, User}

  defstruct users: [], topic: "topic"

  def set_topic(channel_name, user, topic) do
    {:ok, channel} = Registry.get(:channels, channel_name)
    Registry.set :channels, channel_name, struct(channel, %{topic: topic})

    # 332 RPL_TOPIC
    hostname = Application.get_env :hanabi, :hostname
    msg = ":#{hostname} 332 #{user.nick} #{channel_name} #{topic}"
    IRC.broadcast(channel.users, msg)
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

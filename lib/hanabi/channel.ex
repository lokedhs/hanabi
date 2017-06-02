defmodule Hanabi.Channel do
  alias Hanabi.Handler
  alias Hanabi.Registry

  defstruct users: [], topic: "topic"

  def set_topic(channel_name, topic) do
    {:ok, channel} = Registry.get(:channels, channel_name)
    Registry.set :channels, channel_name, struct(channel, %{topic: topic})

    # RPL_TOPIC
    msg = ":irc.localhost 332 lambda #{channel_name} #{topic}"
    Handler.broadcast(channel.users, msg)
  end
end

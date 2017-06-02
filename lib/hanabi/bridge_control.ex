defmodule Hanabi.BridgeControl do
  alias Hanabi.Registry

  @moduledoc """
  @TODO
  """

  ###
  # Interact with the brctl special user

  def register_control_user_handler(pid) do
    # @TODO
  end

  ###
  # Interact with users
  def get_users(), do: Registry.dump(:users)
  def get_user_by_nick(nick) do
    Enum.find(get_users(), fn([{_,user}]) -> user.nick == nick end)
  end
  # -> set properties ?

  ###
  # Interact with channels

  def get_channels(), do: Registry.dump(:channels)
  def get_channel_by_name(name), do: Registry.get(:channels, name)
  def set_topic(channel, topic) do
    # @TODO
  end
end

defmodule Hanabi.Control do
  alias Hanabi.{Registry, User}

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
  def get_users(), do: User.get_all()
  def get_user_by_nick(nick), do: User.get_by_nick(nick)
  # -> set properties ?

  ###
  # Interact with channels

  def get_channels(), do: Registry.dump(:channels)
  def get_channel_by_name(name), do: Registry.get(:channels, name)
  def set_topic(channel, topic) do
    # @TODO
  end
  def add_user(channel, user) do
    # @TODO
  end
end

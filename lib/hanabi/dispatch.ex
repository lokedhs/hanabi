defmodule Hanabi.Dispatch do
  alias Hanabi.Registry

  @hostname Application.get_env :hanabi, :hostname
  @moduledoc """
  Send messages to IRC/Hanabi clients.
  """

  @doc """
  Send a message to an IRC or Hanabi client.
  """
  def send(client, msg) do
    cond do
      Kernel.is_pid(client) -> Kernel.send client, {:msg, msg}
      Kernel.is_port(client) -> send_irc(client, msg)
    end
  end

  # Send a message (`#\{msg\}\\r\\n`) to the given IRC client.
  defp send_irc(client, msg), do: :gen_tcp.send(client, "#{msg}\r\n")

  @doc """
  Send a "reply" (including a code) to an IRC or Hanabi client.
  """
  def reply(client, code, msg) do
    cond do
      Kernel.is_pid(client) ->
        Kernel.send client, {:reply, code, msg}
      Kernel.is_port(client) ->
        send_irc client, ":#{@hostname} #{code} #{msg}"
    end
  end

  @doc """
  Broadcast a message to all channels containing the user.
  """
  def broadcast_for(user_key, msg) do
    {:ok, user} = Registry.get :users, user_key
    Enum.each user.channels, fn(channel_name) ->
      {:ok, channel} = Registry.get :channels, channel_name
      broadcast channel.users, msg
    end
  end

  @doc """
  Broadcast a message to multiple users.

  ## Example

  ```
  users = [{:irc, "lambda", #Port<0.6628>}, {:irc, "fnux", #Port<0.6607>}]
  Hanabi.Dispatch.broadcast(users, "Hello world!")
  ```
  """
  def broadcast(users, msg) do
    Enum.each users, fn(user) ->
      {_type, _, client} = user
      Hanabi.Dispatch.send client, msg
    end
  end
end

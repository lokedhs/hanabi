defmodule Hanabi.Dispatch do
  alias Hanabi.{User, Channel}

  @hostname Application.get_env :hanabi, :hostname
  @moduledoc """
  Send messages to IRC/Hanabi clients.
  """

  @doc """
  Send a message to an IRC or Hanabi client.
  """
  def send(client, msg, sender \\ nil) do
    cond do
      Kernel.is_pid(client) -> send_pid(client, msg, sender)
      Kernel.is_port(client) -> send_port(client, msg)
    end
  end

  # Send a message (`#\{msg\}\\r\\n`) to the given IRC client.
  defp send_port(port, msg), do: :gen_tcp.send(port, "#{msg}\r\n")

  # Send a message to the given process.
  defp send_pid(pid, msg, sender), do:  Kernel.send pid, {:msg, sender, msg}

  @doc """
  Send a "reply" (including a code) to an IRC or Hanabi client.
  """
  def reply(client, code, msg) do
    Hanabi.Dispatch.send client, ":#{@hostname} #{code} #{msg}"
  end

  @doc """
  Broadcast a message to all channels containing the user.
  """
  def broadcast_for(user_key, msg) do
    {:ok, user} = User.get user_key
    Enum.each user.channels, fn(channel_name) ->
      {:ok, channel} = Channel.get channel_name
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
  def broadcast(users, msg, sender \\ nil) do
    Enum.each users, fn(user) ->
      {_type, _, client} = user
      Hanabi.Dispatch.send client, msg, sender
    end
  end
end

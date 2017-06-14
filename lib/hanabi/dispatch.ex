defmodule Hanabi.Dispatch do

  @hostname Application.get_env :hanabi, :hostname
  @moduledoc """
  Dispatch messages to IRC/Bridge clients.
  """

  @doc """
  **IRC only.**
  Send a message (`#\{msg\}\\r\\n`) to the given IRC client.
  """
  def send(client, msg) do
    :gen_tcp.send(client, "#{msg}\r\n")
  end

  @doc """
  **IRC only.**
  Send a "reply" (`:#\{@hosntame\} #\{code\} #\{msg\}\\r\\n`) to an IRC client.
  """
  def reply(client, code, msg) do
    Hanabi.Dispatch.send client, ":#{@hostname} #{code} #{msg}"
  end

  @doc """
  Not yet implemented.
  """
  def broadcast_for(_user, _msg) do
    # Boradcast on all channels containing the user
    :noop
  end

  @doc """
  Broadcast a message to multiple users.

  ## Example
  @TODO
  """
  def broadcast(users, msg) do
    Enum.each users, fn(user) ->
      case user do
        {:irc, _, client} -> Hanabi.Dispatch.send client, msg
        {:bridge, _, pid} -> Kernel.send pid, {:privmsg, msg}
      end
    end
  end
end

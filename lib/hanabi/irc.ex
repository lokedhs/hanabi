defmodule Hanabi.IRC do
  #alias Hanabi.{User, Registry}

  @moduledoc """
    This module allows to send messages to clients.
  """

  @hostname Application.get_env :hanabi, :hostname

  def send(client, msg) do
    :gen_tcp.send(client, "#{msg}\r\n")
  end

  def reply(client, code, msg) do
    :gen_tcp.send(client, ":#{@hostname} #{code} #{msg}\r\n")
  end

  def broadcast_for(_user, _msg) do
    # Boradcast on all channels containing the user
    :noop
  end

  def broadcast(users, msg) do
    Enum.each users, fn(user) ->
      case user do
        {:irc, _, client} -> Hanabi.IRC.send client, msg
        {:bridge, _, pid} -> Kernel.send pid, {:privmsg, msg}
      end
    end
  end
end

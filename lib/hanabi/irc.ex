defmodule Hanabi.IRC do
  #alias Hanabi.{User, Registry}

  @moduledoc """
    See [RFC1459](https://tools.ietf.org/html/rfc1459#section-4.6.3).
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
        _ -> :noop
      end
    end
  end
end

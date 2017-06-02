defmodule Hanabi.User do
  defstruct nick: nil,
    username: nil,
    realname: nil,
    hostname: nil,
    channels: []

  def ident_for(user) do
    username = String.slice(user.username, 0..7)
    ":#{user.nick}!~#{username}@#{user.hostname}"
  end
end

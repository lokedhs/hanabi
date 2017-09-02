defmodule Hanabi.User do
  alias Hanabi.{Registry, User, Channel, IRC}
  alias Hanabi.IRC.Message
  use Hanabi.IRC.Numeric

  @table :hanabi_users # ETS table name, see Hanabi.Registry
  @hostname Application.get_env(:hanabi, :hostname)
  @motd_file Application.get_env(:hanabi, :motd)
  @moduledoc """
  @TODO
  """

  defstruct key: nil,
    nick: nil,
    username: nil,
    realname: nil,
    hostname: nil,
    pass: nil,
    type: :irc,
    port: nil,
    pid: nil,
    channels: []

  ####
  # Registry access

  def get(key), do: Registry.get @table, key

  def get_all(), do: Registry.dump(@table)

  def get_by(field, value) do
    result = Enum.find(get_all(), fn([{_,user}]) -> Map.get(user, field) == value end)
    if result do
      {_key, user} = List.first(result)
      user
    else
      nil
    end
  end

  def update(%User{}=user, value) do
    updated = struct(user, value)
    if Registry.set(@table, user.key, updated), do: updated, else: nil
  end
  def update(key, value) do
    user = User.get key
    if user, do: update(user, value), else: nil
  end

  def set(key, value) do
    case Registry.set(@table, key, value) do
      true -> value
      _ -> nil
    end
  end

  def destroy(key), do: Registry.drop @table, key

  ###

  def send(%User{}, []), do: :noop
  def send(%User{}=user, [%Message{}=msg|tail]) do
    User.send user, msg
    User.send user, tail
  end
  def send(%User{}=user, %Message{}=msg) do
    case user.type do
      :irc -> IRC.send(user.port, msg)
      :virtual -> Kernel.send(user.pid, msg)
    end
  end
  def send(userkey, %Message{}=msg) do
    user = User.get(userkey)
    if user, do: User.send(user, msg), else: :err
  end

  def broadcast(%User{}=user, %Message{}=msg) do
    User.send user, msg
    for channel <- user.channels do
      Channel.broadcast(channel, msg)
    end
  end

  ###
  # Utils

  def ident_for(%User{}=user) do
    username = String.slice(user.username, 0..7)
    "#{user.nick}!~#{username}@#{user.hostname}"
  end

  def is_in_use?(field, value) do
    case get_by(field, value) do
      {:ok, _} -> true
      _ -> false
    end
  end

  ###
  # Specific actions

  def set_nick(user, nick) do
    case IRC.validate(:nick, nick) do
      @err_erroneusnickname ->
        err = %Message{
          prefix: @hostname,
          command: @err_erroneusnickname,
          middle: user.nick,
          trailing: "Erroneus nickname"
        }
        User.send user, err
      @err_nicknameinuse ->
        err = %Message{
          prefix: @hostname,
          command: @err_nicknameinuse,
          middle: user.nick,
          trailing: "Nickname is already in use"
        }
        User.send user, err
      :ok ->
        User.update(user, nick: nick)

        rpl = %Message{
          prefix: user.nick, # Old nick
          command: "NICK",
          middle: nick # New nick
        }

        # Only if the user already have a nickname
        if user.nick, do: User.broadcast user, rpl
    end
  end

  def set_pass(user, pass) do
    User.update(user, pass: pass)
  end

  def register(:irc, user, %Message{}=msg) do
    regex = ~r/^(\w*)\s(\w*)\s(\S*)$/ui
    if String.match?(msg.middle, regex) && msg.trailing do
      [_, username, _hostname, _servername]
      = Regex.run(regex, msg.middle)

      realname = msg.trailing
      hostname = IRC.resolve_hostname(user.port)

      register :irc, user, username, hostname, realname
    else
      err = %Message{
        prefix: @hostname,
        command: @err_needmoreparams,
        middle: "USER",
        trailing: "Not enough parameters"
      }
      User.send user, err
    end
  end
  def register(:irc, user, username, hostname, realname) do
    unless is_in_use?(:username, username) do
      User.update(user, %{username: username,
        realname: realname,
        hostname: hostname})
      else
      err = %Message{
        prefix: @hostname,
        command: @err_alreadyregistered,
        middle: user.nick,
        trailing: "You may not reregister"
      }
      User.send user, err
    end
  end

  def send_privmsg(%User{}=sender, %Message{}=msg) do
    recipient_nick = msg.middle
    recipient = User.get_by(:nick, recipient_nick)

    if recipient do
      privmsg = %Message{
        prefix: ident_for(sender),
        command: "PRIVMSG",
        middle: recipient_nick,
        trailing: msg.trailing
      }
      User.send recipient, privmsg
    else
      err = %Message{
        prefix: @hostname,
        command: @err_nosuchnick,
        middle: "#{sender.nick} #{recipient_nick}",
        trailing: "No such nick/channel"
      }
      User.send sender, err
    end
  end

  def send_motd(%User{}=user) do
    if File.exists?(@motd_file) do
      lines = File.stream!(@motd_file) |> Stream.map(&String.trim/1)

      #RPL_MOTDSTART
      User.send user, %Message{
        prefix: @hostname,
        command: @rpl_motdstart,
        middle: user.nick,
        trailing: "- #{@hostname} Message of the day - "
      }

      #RPL_MOTD
      for line <- lines do
      User.send user, %Message{
          command: @rpl_motd,
          prefix: @hostname,
          middle: user.nick,
          trailing: "- " <> line
        }
      end

      #RPL_ENDOFMOTD
      User.send user, %Message{
        prefix: @hostname,
        command: @rpl_endofmotd,
        middle: user.nick,
        trailing: "End of /MOTD command"
      }
    else
      User.send user, %Message{
        prefix: @hostname,
        command: @err_nomotd,
        middle: user.nick,
        trailing: "MOTD File is missing"
      }
    end
  end

#  def quit(user_id, part_message) do
#    {:ok, user} = User.get(user_id)
#
#    # Broadcast part message
#    User.broadcast(user, part_message)
#
#    Enum.each user.channels, fn(channel) ->
#      part_channel(user, channel, part_message)
#    end
#
#    # Destroy user
#    User.drop(user_id)
#
#    # Close connection.
#    :gen_tcp.close(user.port)
#  end
end

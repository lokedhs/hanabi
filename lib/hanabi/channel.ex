defmodule Hanabi.Channel do
  alias Hanabi.{User, Channel, IRC, Registry}
  alias Hanabi.IRC.Message
  use Hanabi.IRC.Numeric

  @hostname Application.get_env(:hanabi, :hostname)
  @table :hanabi_channels # ETS table, see Hanabi.Registry
  @moduledoc """
  @TODO
  """

  defstruct name: nil, users: [], topic: "", relay_to: [:irc, :virtual]

  ####
  # Registry access

  def get(key), do: Registry.get @table, key

  def get_all(), do: Registry.dump @table

  def update(%Channel{}=channel, change) do
    updated = struct(channel, change)
    if Registry.set(@table, channel.name, updated), do: updated, else: nil
  end
  def update(key, change) do
    channel = Channel.get key
    if channel, do: update(channel, change), else: nil
  end

  def set(key, value), do: Registry.set @table, key, value

  def drop(key), do: Registry.drop @table, key

  ###

  def broadcast(%Channel{}=channel, %Message{}=msg) do
    for user <- channel.users do
      User.send user, msg
    end
  end

  ###
  # Specific actions

  def join(%User{}=user, %Message{}=msg) do
    channel_name = msg.middle
    if IRC.validate(:channel, channel_name) == :ok do
      channel = case Channel.get(channel_name) do
        nil -> struct(Channel, name: channel_name)
        channel -> channel
      end

      channel = Channel.add_user(user, channel)

      rpl_topic = %Message{
        prefix: @hostname,
        command: @rpl_topic,
        middle: "#{user.nick} #{channel.name}",
        trailing: channel.topic
      }

      User.send user, rpl_topic
      send_names(user, channel)
    else
      err = %Message{
        prefix: @hostname,
        command: @err_nosuchchannel,
        middle: channel_name,
        trailing: "No such channel"
      }
      User.send user, err
    end
  end

  defp get_names(userkeys, names \\ nil)
  defp get_names([], names), do: names
  defp get_names([userkey|tail], names) do
    name = User.get(userkey) |> Map.get(:nick)
    concatenated = if names, do: "#{names} #{name}", else: name
    get_names tail, concatenated
  end

  def send_names(%User{}=user, %Message{}=msg) do
    channel = Channel.get(msg.middle)
    send_names(user, channel)
  end

  def send_names(%User{}=user, %Channel{}=channel) do
      names = get_names(channel.users)
      rpl_namreply = %Message{
        prefix: @hostname,
        command: @rpl_namreply,
        middle: "#{user.nick} = #{channel.name}",
        trailing: names
      }

      rpl_endofnames = %Message{
        prefix: @hostname,
        command: @rpl_endofnames,
        middle: "#{user.nick} #{channel.name}",
        trailing: "End of /NAMES list"
      }

      User.send user, [rpl_namreply, rpl_endofnames]
  end

  def add_user(%User{}=user, %Channel{}=channel) do
    channel = Channel.update channel, users: channel.users ++ [user.key]
    User.update user, channels: user.channels ++ [channel.name]

    join_msg = %Message{
      prefix: User.ident_for(user),
      command: "JOIN",
      middle: channel.name
    }
    Channel.broadcast(channel, join_msg)

    channel
  end

  def part(%User{}=user, %Message{}=msg) do
    if String.match?(msg.middle, ~r/^(#\w*(,#\w*)?)*$/ui) do
      channel_names = String.split(msg.middle, ",")

      for channel_name <- channel_names do
        case Channel.remove_user(user, channel_name, msg.trailing) do
          {:err, code, explanation} ->
            err = %Message{
              prefix: @hostname,
              command: code,
              middle: channel_name,
              trailing: explanation
            }
            User.send user, err
          _ -> :noop
        end
      end
    else
      err = %Message{
        prefix: @hostname,
        command: @err_needmoreparams,
        middle: "PART",
        trailing: "Not enough parameters"
      }
      User.send user, err
    end
  end

  def remove_user(user, channel, part_msg \\ nil)
  def remove_user(%User{}=user, %Channel{}=channel, part_msg) do
    if (user.key in channel.users) do
      Channel.update channel, users: List.delete(channel.users, user.key)
      User.update user, channels: List.delete(user.channels, channel.name)

      Channel.broadcast channel, %Message{
        prefix: User.ident_for(user),
        command: "PART",
        middle: channel.name,
        trailing: part_msg
      }

      # Returns
      :ok
    else
      {:err, @err_notonchannel, "You're not on that channel"}
    end
  end

  def remove_user(%User{}=user, channel_name, part_msg) do
    channel = Channel.get(channel_name)
    if channel do
      remove_user(user, channel, part_msg)
    else
      {:err, @err_nosuchchannel, "No such channel"}
    end
  end

  def send_privmsg(%User{}=sender, %Message{}=msg) do
    channel_name = msg.middle
    channel = Channel.get channel_name

    if channel do
      privmsg = %Message{
        prefix: User.ident_for(sender),
        command: "PRIVMSG",
        middle: channel_name,
        trailing: msg.trailing
      }

      # Remove sender from receivers !
      channel = struct(channel, users: List.delete(channel.users, sender.key))
      Channel.broadcast channel, privmsg
    else
      err = %Message{
        prefix: @hostname,
        command: @err_nosuchnick,
        middle: "#{sender.nick} #{channel_name}",
        trailing: "No such nick/channel"
      }
      User.send sender, err
    end
  end

  def set_topic(%User{}=user, %Message{}=msg) do
    channel_name = msg.middle
    channel = Channel.get channel_name

    if (channel && user.key in channel.users) do
      channel = Channel.update channel, topic: channel = msg.trailing
      rpl_topic = %Message{
        prefix: @hostname,
        command: @rpl_topic,
        middle: "#{user.nick} #{channel.name}",
        trailing: channel.topic
      }
      Channel.broadcast channel, rpl_topic
    else
      err = %Message{
        prefix: @hostname,
        command: @err_notonchannel,
        middle: "#{user.nick} #{channel_name}",
        trailing: "You're not on that channel"
      }
      User.send user, err
    end
  end
end

defmodule Hanabi.Handler do
  require Logger
  use GenEvent
  alias Hanabi.{User, Channel, Registry, IRC}

  @moduledoc false

  def handle_event({ event, parts, client }, messages) do
    { :ok, [{event, parts, client} | messages ]}
  end

  def handle_call(:messages, messages) do
    { :ok, messages, [] }
  end

  def handle_events do
    stream = GenEvent.stream(Events)
    for event <- stream do
      case event do
        { "PING", [name], client } ->
          handle_ping(client, name)
        { "NICK", [nick], client } ->
          handle_nick(client, nick)
        { "JOIN", [channel], client } ->
          handle_join(client, channel)
        { "PART", [channel | part_message], client } ->
          handle_part(client, channel, part_message)
        { "WHO", [channel], client } ->
          handle_who(client, channel)
        { "PRIVMSG", [channel | parts ], client } ->
          handle_privmsg(client, channel, parts)
        { "TOPIC", [channel | topic_parts], client } ->
          handle_topic(client, channel, topic_parts)
        { "QUIT", parts, client } ->
          handle_quit(client, ["QUIT" | parts])
        _ ->
          Logger.warn "Unhandled event !"
          IO.inspect(event)
      end
    end
  end

  #################
  # Handling stuff

  defp handle_nick(client, nick) do
    {:ok, user} = Registry.get :users, client
    validation_regex = ~r/\A[a-z_\-\[\]\\^{}|`][a-z0-9_\-\[\]\\^{}|`]{2,15}\z/
    cond do
      !String.match?(nick, validation_regex) ->
        # 432 ERR_ERRONEUSNICKNAME
        IRC.reply(client, 432, "#{nick} :Erroneus nickname")
      User.get_by_nick(nick) != nil ->
        # 433 ERR_NICKNAMEINUSE
        IRC.reply(client, 433, "#{nick} :Nickname is already in use")
      true -> User.set_nick(client, user, nick)
    end
  end

  defp handle_ping(client, name) do
    IRC.send(client, "PONG #{name}")
  end

  defp handle_join(client, channel_name) do
    User.join_channel(client, channel_name)
  end

  defp handle_part(client, channel_name, part_message) do
    part_message = Enum.join(part_message, " ")
    User.part_channel(client, channel_name, part_message)
  end

  defp handle_privmsg(client, dst, parts) do
    msg = Enum.join(parts, " ")

    if String.match?(dst, ~r/^#.*$/) do # PRIVMSG to a channel
      Channel.privmsg(client, dst, msg)
    else # PRIVMSG to an user
      User.privmsg(client, dst, msg)
    end
  end

  defp handle_who(_socket, _channel) do
    # @TODO
  end

  defp handle_topic(client, channel_name, topic_parts) do
    topic = Enum.join(topic_parts, " ")
    {:ok, user} = Registry.get :users, client
    Channel.set_topic(channel_name, user, topic)
  end

  defp handle_quit(client, parts) do
    part_message = Enum.join(parts, "")
    User.quit(client, part_message)
  end
end

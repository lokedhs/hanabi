defmodule Hanabi.Control do
  alias Hanabi.{Registry, User, Channel}

  @moduledoc """
  This module allows you to interact with the IRC server.
  """

  ###
  # Interact with users

  @doc """
    Register an user under the nickname `nick`. Any message
  send this user on IRC will be send to `pid` using `Kernel.send/2`.

  ## Messages
    * @TODO
    * @TODO

  ## Example
  ```
  defmodule MyUserHandler do
     use GenServer

    def start_link do
      GenServer.start_link(__MODULE__, :ok)
    end

    def init(:ok) do
      # Register itself as user "lambda"
      Hanabi.Control.register("lambda", self())
      {:ok, nil}
    end

    def handle_info(%{privmsg: privmsg, sender: sender}, state) do
      IO.puts "New message : #\{privmsg\}"
      # do stuff

      {:noreply, state}
    end

    def handle_info(_msg, state) do
      {:noreply, state}
    end
  end
  ```
  """
  def register_user(nick, pid) do
    hostname = Application.get_env :hanabi, :hostname
    user = struct(User, %{nick: nick, type: :bridge, hostname: hostname})
    Registry.set :users, pid, user
  end

  @doc """
  Get all the users registered on the IRC server.

  ## Example
  ```
  iex> Hanabi.Control.get_users()
[[{#Port<0.6679>,
   %Hanabi.User{channels: ["#testchannel"], hostname: 'localhost',
    nick: "lambda", realname: nil, type: :irc, username: "lambda"}}],
 [{#Port<0.6645>,
   %Hanabi.User{channels: ["#testchannel", "#secondtestchannel"],
    hostname: 'localhost', nick: "fnux", realname: nil, type: :irc,
    username: "fnux"}}]]
  ```
  """
  def get_users(), do: User.get_all()

  @doc """
  Find an user on the IRC server given its nickname.

  ## Example
  ```
  iex> Hanabi.Control.get_user_by_nick("fnux")
[{#Port<0.6645>,
  %Hanabi.User{channels: ["#testchannel", "#secondtestchannel"],
   hostname: 'localhost', nick: "fnux", realname: nil, type: :irc,
   username: "fnux"}}]

  ```
  """
  def get_user_by_nick(nick), do: User.get_by_nick(nick)

  ###
  # Interact with channels

  @doc """
  Get all the active channels of the IRC server.

  ## Example
  ```
  iex> Hanabi.Control.get_channels()
  [[{"#testchannel",
   %Hanabi.Channel{topic: "topic",
    users: [{:irc, "fnux", #Port<0.6645>}, {:irc, "lambda", #Port<0.6679>}]}}],
  [{"#secondtestchannel",
   %Hanabi.Channel{topic: ":vlurps", users: [{:irc, "fnux", #Port<0.6645>}]}}]]
  ```
  """
  def get_channels(), do: Registry.dump(:channels)

  @doc """
  Find a channel given its name.

  ## Examples
  ```
  iex> Hanabi.Control.get_channel_by_name("#testchannel")
  {:ok,
 %Hanabi.Channel{topic: "topic",
  users: [{:irc, "fnux", #Port<0.6645>}, {:irc, "lambda", #Port<0.6679>}]}}

  iex> Hanabi.Control.get_channel_by_name("#nonexistantchannel")
  {:error, :not_found}
  ```
  """
  def get_channel_by_name(name), do: Registry.get(:channels, name)

  @doc """
  Set the topic of a channel given its name.,

  ## Example
  ```
  Hanabi.Control.set_topic("#testchannel", "Let's try a few things...")
  ```

  """
  def set_topic(channel, topic) do
    Channel.set_topic(channel, nil, topic)
  end

  @doc """
  Add an user to the given channel, messages will be send
  to the process `pid` as for `Hanabi.register_user/2`.

  ## Example
  ```
  user = {:bridge, "mynick", pid}
  Hanabi.Control.add_user_to_channel("#testchannel", user)
  ```
  """
  def add_user_to_channel(channel, user) do
    Channel.add_user(channel, user)
  end

  @doc """
  Remove an user from the given channel.

  ## Example

  @TODO
  """
  def remove_user_from_channel(channel, user, part_msg \\ "") do
    Channel.remove_user(channel, user, part_msg)
  end
end

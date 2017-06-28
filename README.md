# Hanabi

Hanabi is a (work in progress) IRC server designed to build bridges between
services.

## Useful links

  * Documentation [on hexdocs.pm](https://hexdocs.pm/hanabi/readme.html).
  * [RFC1459](https://tools.ietf.org/html/rfc1459) : Internet Relay Chat
  Protocol.
  * Parts of the IRC-related code were inspired by
[radar/elixir-irc](https://github.com/radar/elixir-irc).

## Usage & configuration

You must add (and fill) the following to your `config/config.exs` file :

```
config :hanabi, port: 6667,
                hostname: "my.awesome.hostname",
                motd: "/path/to/motd.txt"
```

You only have to add `hanabi` in the dependency section of your `mix.exs` file.
You can add `:hanabi` to `:extra_applications` in order to start it automatically,
otherwise you would have to use `Hanabi.start()`.

Any other interaction with `Hanabi` should use the `Hanabi.Control` module.

## Struture

Hanabi is splitted in a few modules, most of them are not displayed in the
generated ([here](https://hexdocs.pm/hanabi/readme.html)) documentation since they are not supposed
to be used to be used out of Hanabi. Feel free to take to look to the [source
code](https://github.com/Fnux/hanabi).

  * `Hanabi` :
  * `Hanabi.Registry` :
  * `Hanabi.Server` :
  * `Hanabi.Handler` :
  * `Hanabi.User` :
  * `Hanabi.Channel` :
  * `Hanabi.Dispatch` :
  * `Hanabi.Control` :

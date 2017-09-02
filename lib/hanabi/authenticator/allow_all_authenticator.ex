defmodule Hanabi.Authenticator.AllowAllAuthenticator do
  def authentication_required? do
    false
  end

  def valid?(user) do
    true
  end
end

defmodule BotArmyFeeds.Repo do
  @moduledoc """
  Ecto repository for bot_army_feeds.
  """

  use Ecto.Repo,
    otp_app: :bot_army_feeds,
    adapter: Ecto.Adapters.Postgres
end

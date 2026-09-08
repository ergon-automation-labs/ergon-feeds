import Config

# Logger with correlation_id support
config :logger,
  level: :info,
  backends: [:console]

config :logger, :console,
  format: "[$time] [$level] $message\n",
  metadata: [:correlation_id]

config :bot_army_feeds, :deployment_status, "experimental"

# Ecto. Database: convention chain per RuntimeDbConfig (see runtime.exs for
# the boot override — config.exs env reads are baked at BUILD time, so the
# DATABASE_* env from the compose/launchd environment only takes effect via
# runtime.exs). Defaults match postgres-init/01-create-databases.sql.
config :bot_army_feeds, ecto_repos: [BotArmyFeeds.Repo]

config :bot_army_feeds, BotArmyFeeds.Repo,
  database: System.get_env("BOT_ARMY_FEEDS_BOT_DB_NAME") || "bot_army_feeds",
  hostname: System.get_env("BOT_ARMY_FEEDS_BOT_DB_HOST") || "127.0.0.1",
  port: String.to_integer(System.get_env("BOT_ARMY_FEEDS_BOT_DB_PORT") || "5432"),
  username: System.get_env("BOT_ARMY_FEEDS_BOT_DB_USER") || "postgres",
  password: System.get_env("BOT_ARMY_FEEDS_BOT_DB_PASSWORD") || "postgres"


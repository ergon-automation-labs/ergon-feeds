import Config

# Database overrides evaluated at BOOT (compose .env / launchd plist env).
# NOTE: config.exs env reads are baked into sys.config at BUILD time — the
# boot override here is the only place runtime env can take effect. Mirror
# of internal_docs' runtime.exs (24c2251); key chain per RuntimeDbConfig
# convention: <PREFIX>_DB_* → DATABASE_*. Prefix = service name "feeds_bot".
prefix = "BOT_ARMY_FEEDS_BOT"

db_name = System.get_env("#{prefix}_DB_NAME") || System.get_env("DATABASE_NAME")

if db_name do
  config :bot_army_feeds, BotArmyFeeds.Repo,
    database: db_name,
    hostname:
      System.get_env("#{prefix}_DB_HOST") || System.get_env("DATABASE_HOST") || "127.0.0.1",
    port:
      (System.get_env("#{prefix}_DB_PORT") || System.get_env("DATABASE_PORT") || "5432")
      |> String.to_integer(),
    username: System.get_env("#{prefix}_DB_USER") || System.get_env("DATABASE_USER"),
    password: System.get_env("#{prefix}_DB_PASSWORD") || System.get_env("DATABASE_PASSWORD")
end
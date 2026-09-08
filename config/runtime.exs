import Config

# Database overrides evaluated at BOOT (compose .env / launchd plist env).
# NOTE: config.exs env reads are baked into sys.config at BUILD time — the
# boot override here is the only place runtime env can take effect. Mirror
# of internal_docs' runtime.exs (24c2251); key chain per RuntimeDbConfig
# convention: <PREFIX>_DB_* → DATABASE_*. Prefix = service name "feeds_bot".
#
# UNCONDITIONAL (unlike internal_docs' version): ArticleStore.init queries
# the repo during boot, so a wrong hostname here is an immediate hard crash
# (RERUN13: pool hit the baked 127.0.0.1 fallback → econnrefused ×11
# because the VM .env sets DATABASE_HOST but never DATABASE_NAME, which
# internal_docs used as its firing gate — its lazy pool merely masked the
# same gap). Every key gets the same chain; the fallbacks mirror config.exs.
prefix = "BOT_ARMY_FEEDS_BOT"

config :bot_army_feeds, BotArmyFeeds.Repo,
  database:
    System.get_env("#{prefix}_DB_NAME") || System.get_env("DATABASE_NAME") || "bot_army_feeds",
  hostname:
    System.get_env("#{prefix}_DB_HOST") || System.get_env("DATABASE_HOST") || "127.0.0.1",
  port:
    (System.get_env("#{prefix}_DB_PORT") || System.get_env("DATABASE_PORT") || "5432")
    |> String.to_integer(),
  username: System.get_env("#{prefix}_DB_USER") || System.get_env("DATABASE_USER") || "postgres",
  password:
    System.get_env("#{prefix}_DB_PASSWORD") || System.get_env("DATABASE_PASSWORD") || "postgres"
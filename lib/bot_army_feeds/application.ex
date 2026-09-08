defmodule BotArmyFeeds.Application do
  @moduledoc """
  bot_army_feeds application supervisor.

  Manages:
  - RSS feed polling and article storage
  - GenBot for markdown-driven LLM skills
  """

  use Application

  @env Mix.env()

  @impl true
  def start(_type, _args) do
    # APPEND order = start order: the Repo must come FIRST — ArticleStore's
    # init queries it, and the old prepend chain put Repo last (RERUN13:
    # "could not lookup Ecto repo BotArmyFeeds.Repo because it was not
    # started", ArticleStore.init → load_all).
    children =
      []
      |> maybe_add_repo()
      |> maybe_add_feed_store()
      |> maybe_add_article_store()
      |> maybe_add_poller()
      |> maybe_add_consumer()
      |> maybe_add_gen_bot()

    opts = [strategy: :one_for_one, name: BotArmyFeeds.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_add_repo(children) do
    if @env == :test, do: children, else: children ++ [BotArmyFeeds.Repo]
  end

  defp maybe_add_feed_store(children) do
    if @env == :test, do: children, else: children ++ [{BotArmyFeeds.Stores.FeedStore, []}]
  end

  defp maybe_add_article_store(children) do
    if @env == :test, do: children, else: children ++ [{BotArmyFeeds.Stores.ArticleStore, []}]
  end

  defp maybe_add_poller(children) do
    if @env == :test, do: children, else: children ++ [{BotArmyFeeds.Poller, []}]
  end

  defp maybe_add_consumer(children) do
    if @env == :test, do: children, else: children ++ [{BotArmyFeeds.NATS.Consumer, []}]
  end

  defp maybe_add_gen_bot(children) do
    # GenBot is a __using__ macro module (no child_spec/1) — the concrete
    # instance below is what carries the generated GenServer + child_spec.
    # See GenBotInstance's moduledoc (phase-04 pack matrix crash, 2026-09-08).
    if @env == :test, do: children, else: [{BotArmyFeeds.GenBotInstance, []} | children]
  end
end

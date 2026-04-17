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
    if @env == :test, do: children, else: [BotArmyFeeds.Repo | children]
  end

  defp maybe_add_feed_store(children) do
    if @env == :test, do: children, else: [{BotArmyFeeds.Stores.FeedStore, []} | children]
  end

  defp maybe_add_article_store(children) do
    if @env == :test, do: children, else: [{BotArmyFeeds.Stores.ArticleStore, []} | children]
  end

  defp maybe_add_poller(children) do
    if @env == :test, do: children, else: [{BotArmyFeeds.Poller, []} | children]
  end

  defp maybe_add_consumer(children) do
    if @env == :test, do: children, else: [{BotArmyFeeds.NATS.Consumer, []} | children]
  end

  defp maybe_add_gen_bot(children) do
    if @env == :test, do: children, else: [{BotArmyFeeds.GenBot, []} | children]
  end
end

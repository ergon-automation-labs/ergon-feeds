defmodule BotArmyFeeds.NATS.Consumer do
  @moduledoc """
  NATS consumer for bot_army_feeds.

  Subscribes to:
  - `feeds.feed.add` - Add a new feed
  - `feeds.feed.remove` - Remove a feed
  - `feeds.feed.update` - Update feed config
  - `feeds.feed.list` - List all feeds (request/reply)
  - `feeds.poll` - Trigger immediate poll
  - `events.llm.response.parsed` - LLM research results

  Publishes:
  - `events.feeds.article.ingested` - When article is parsed
  - `events.feeds.article.researched` - When research is complete
  - `events.feeds.topic.discovered` - Interesting topics found
  """

  use GenServer
  require Logger

  alias BotArmyFeeds.Stores.FeedStore
  alias BotArmyFeeds.Handlers.ResearchHandler
  alias BotArmyRuntime.NATS.Connection

  @version Mix.Project.config()[:version]
  @registry_heartbeat_ms 20_000

  @subjects [
    %{subject: "feeds.feed.add", type: :subscribe, description: "Add feed"},
    %{subject: "feeds.feed.remove", type: :subscribe, description: "Remove feed"},
    %{subject: "feeds.feed.update", type: :subscribe, description: "Update feed"},
    %{subject: "feeds.feed.list", type: :request_reply, description: "List feeds"},
    %{subject: "feeds.poll", type: :subscribe, description: "Poll feeds"},
    %{subject: "events.llm.response.parsed", type: :subscribe, description: "LLM response parsed"}
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    tenant_id = Keyword.get(opts, :tenant_id)
    user_id = Keyword.get(opts, :user_id)

    Logger.info("Starting NATS Consumer for bot_army_feeds")

    # Get NATS connection
    case GenServer.call(Connection, :get_connection, 5000) do
      {:ok, conn} ->
        # Setup subscriptions
        subscriptions = [
          {Gnat.sub(conn, self(), "feeds.feed.add"), :feed_add},
          {Gnat.sub(conn, self(), "feeds.feed.remove"), :feed_remove},
          {Gnat.sub(conn, self(), "feeds.feed.update"), :feed_update},
          {Gnat.sub(conn, self(), "feeds.feed.list"), :feed_list},
          {Gnat.sub(conn, self(), "feeds.poll"), :poll},
          {Gnat.sub(conn, self(), "events.llm.response.parsed"), :llm_response}
        ]

        Logger.info("Subscribed to feed management subjects")
        BotArmyRuntime.Registry.register("feeds", @subjects, @version)
        Process.send_after(self(), :registry_heartbeat, @registry_heartbeat_ms)

        {:ok,
         %{
           conn: conn,
           subscriptions: subscriptions,
           tenant_id: tenant_id,
           user_id: user_id
         }}

      {:error, reason} ->
        Logger.error("Failed to get NATS connection: #{inspect(reason)}")
        {:stop, :nats_connection_failed}
    end
  end

  @impl true
  def handle_info({:msg, msg}, state) do
    BotArmyRuntime.Tracing.with_consumer_span(msg.topic, Map.get(msg, :headers, []), fn ->
      decoded = BotArmyCore.NATS.Decoder.decode(msg.body)

      case decoded do
        {:ok, payload} ->
          route_message(payload, msg.reply_to, state)

        {:error, reason} ->
          Logger.warning("Failed to decode NATS message: #{inspect(reason)}")
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(:registry_heartbeat, state) do
    if state.subscriptions != [] do
      BotArmyRuntime.Registry.register("feeds", @subjects, @version)
      Process.send_after(self(), :registry_heartbeat, @registry_heartbeat_ms)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Message routing with reply_to
  defp route_message(%{"event" => "feeds.feed.add"} = payload, reply_to, _state) do
    with {:ok, feed} <- FeedStore.create(payload) do
      publish_feed_event("feed.added", feed)
      Logger.info("Added feed: #{feed.name}")
      send_reply(reply_to, %{ok: true, message: "Feed added"})
    else
      {:error, _} = error ->
        Logger.warning("Failed to add feed: #{inspect(error)}")
        send_reply(reply_to, %{ok: false, message: "Failed to add feed"})
    end
  end

  defp route_message(%{"event" => "feeds.feed.remove"} = payload, reply_to, _state) do
    url = Map.get(payload, "url")

    with {:ok, feed} <- FeedStore.get_by_url(url) |> elem(1) do
      FeedStore.remove(feed.id)
      publish_feed_event("feed.removed", feed)
      Logger.info("Removed feed: #{feed.name}")
      send_reply(reply_to, %{ok: true, message: "Feed removed"})
    else
      :error ->
        Logger.warning("Feed not found for removal: #{url}")
        send_reply(reply_to, %{ok: false, message: "Feed not found"})
    end
  end

  defp route_message(%{"event" => "feeds.feed.update"} = payload, reply_to, _state) do
    url = Map.get(payload, "url")

    with {:ok, feed} <- FeedStore.get_by_url(url) |> elem(1) do
      attrs = Map.delete(payload, "url")

      with {:ok, updated} <- FeedStore.update(feed.id, attrs) do
        publish_feed_event("feed.updated", updated)
        Logger.info("Updated feed: #{feed.name}")
        send_reply(reply_to, %{ok: true, message: "Feed updated"})
      end
    else
      :error ->
        Logger.warning("Feed not found for update: #{url}")
        send_reply(reply_to, %{ok: false, message: "Feed not found"})
    end
  end

  defp route_message(%{"event" => "feeds.feed.list"} = _payload, reply_to, _state) do
    {:ok, feeds} = FeedStore.list()

    reply = %{
      "ok" => true,
      "feeds" => Enum.map(feeds, &feed_to_map/1)
    }

    send_reply(reply_to, reply)
  end

  defp route_message(%{"event" => "feeds.poll"} = _payload, reply_to, _state) do
    BotArmyFeeds.Poller.run_fetch()
    send_reply(reply_to, %{ok: true, message: "Feed poll triggered"})
  end

  defp route_message(%{"event" => "events.llm.response.parsed"} = payload, _reply_to, _state) do
    # Route LLM research response to the research handler
    case ResearchHandler.handle_research_response(payload) do
      {:ok, result} -> Logger.debug("Research completed: #{inspect(result)}")
      {:error, reason} -> Logger.warning("Research failed: #{inspect(reason)}")
    end
  end

  defp route_message(_message, _reply_to, _state) do
    :ignore
  end

  # Helper functions
  defp feed_to_map(feed) do
    %{
      "id" => feed.id,
      "url" => feed.url,
      "name" => feed.name,
      "category" => feed.category,
      "tags" => feed.tags,
      "enabled" => feed.enabled,
      "last_polled" => feed.last_polled,
      "error_count" => feed.error_count,
      "inserted_at" => feed.inserted_at
    }
  end

  defp publish_feed_event(event, feed) do
    payload = %{
      "event" => "events.feeds.#{event}",
      "event_id" => UUID.uuid4() |> to_string(),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "source" => "bot_army_feeds",
      "payload" => %{
        "feed_id" => feed.id,
        "feed_name" => feed.name
      }
    }

    BotArmyRuntime.NATS.Publisher.publish("events.feeds.#{event}", payload)
  end

  defp send_reply(nil, _payload) do
    :ok
  end

  defp send_reply(reply_to, payload) when is_binary(reply_to) do
    case BotArmyRuntime.NATS.Publisher.publish(reply_to, payload) do
      :ok -> :ok
      {:error, reason} -> Logger.warning("Failed to send reply: #{inspect(reason)}")
    end
  end
end

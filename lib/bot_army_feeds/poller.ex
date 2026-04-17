defmodule BotArmyFeeds.Poller do
  @moduledoc """
  GenServer that periodically polls configured RSS feeds for new articles.

  Checks all configured feeds every 15 minutes, filters out seen GUIDs,
  and publishes new articles for ingestion.
  """

  use GenServer
  require Logger

  alias BotArmyFeeds.{Stores.FeedStore, Stores.ArticleStore, NATS.Publisher}
  import SweetXml

  # 15 minutes
  @check_interval_ms 900_000
  @http_timeout_ms 15_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Trigger a fetch run now (e.g., from NATS feeds.poll request).
  """
  def run_fetch do
    GenServer.cast(__MODULE__, :fetch)
  end

  @impl true
  def init(_) do
    Logger.info("Starting RSS Poller - checking every #{@check_interval_ms}ms (15 minutes)")
    schedule_poll()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:poll, state) do
    poll_feeds()
    schedule_poll()
    {:noreply, state}
  end

  @impl true
  def handle_cast(:fetch, state) do
    poll_feeds()
    {:noreply, state}
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @check_interval_ms)
  end

  defp poll_feeds do
    try do
      feeds = FeedStore.list() |> elem(1)
      Logger.info("Polling #{length(feeds)} RSS feeds")

      Enum.each(feeds, &poll_feed/1)
    rescue
      error ->
        Logger.error("Error polling RSS feeds: #{inspect(error)}")
    end
  end

  defp poll_feed(feed) do
    unless feed.enabled do
      Logger.debug("Skipping disabled feed: #{feed.name}")
      :ok
    else
      case fetch_feed(feed.url) do
        {:ok, items} ->
          Logger.info("Fetched #{length(items)} items from #{feed.name} (#{feed.url})")

          items
          |> Enum.filter(fn item ->
            # Check if article with this GUID already exists for this feed
            case ArticleStore.mark_seen(feed.id, item["guid"]) do
              :ok -> true
              {:error, :already_exists} -> false
            end
          end)
          |> Enum.each(fn item ->
            handle_new_item(item, feed)
          end)

        {:error, reason} ->
          Logger.warning("RSS poll failed for #{feed.name} (#{feed.url}): #{inspect(reason)}")
          update_error_count(feed.id)
      end
    end
  end

  defp fetch_feed(url) do
    with {:ok, {{_http, 200, _status}, _headers, body}} <-
           :httpc.request(:get, {String.to_charlist(url), []}, [{:timeout, @http_timeout_ms}], []),
         {:ok, items} <- parse_feed(body) do
      {:ok, items}
    else
      {:ok, {{_http, status, _status}, _headers, _body}} ->
        Logger.warning("HTTP error fetching #{url}: status #{status}")
        {:error, {:http_error, status}}

      {:error, reason} ->
        Logger.error("Failed to fetch #{url}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_feed(body) when is_binary(body) do
    case SweetXml.parse(body) do
      {:ok, doc} ->
        parse_items(doc)

      {:error, reason} ->
        Logger.error("Failed to parse XML: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_feed(_body), do: {:error, :invalid_body}

  defp parse_items(doc) do
    # Try RSS 2.0 <item> format first
    items =
      doc
      |> SweetXml.xpath(~x"//item"l,
        guid: ~x"guid/text()"s,
        title: ~x"title/text()"s,
        link: ~x"link/text()"s,
        description: ~x"description/text()"s,
        pub_date: ~x"pubDate/text()"s
      )

    # If no items, try Atom <entry> format
    items =
      if Enum.empty?(items) do
        doc
        |> SweetXml.xpath(~x"//entry"l,
          guid: ~x"id/text()"s,
          title: ~x"title/text()"s,
          link: ~x"link[@rel='alternate']/@href"s,
          description: ~x"summary/text()"s,
          pub_date: ~x"published/text()"s
        )
      else
        items
      end

    # Normalize to map format with string keys
    normalized =
      Enum.map(items, fn item ->
        %{
          "guid" => to_string(item[:guid] || ""),
          "title" => to_string(item[:title] || ""),
          "url" => to_string(item[:link] || ""),
          "description" => to_string(item[:description] || ""),
          "published_at" => to_string(item[:pub_date] || "")
        }
      end)
      |> Enum.filter(&(String.length(Map.get(&1, "guid", "")) > 0))

    {:ok, normalized}
  end

  defp handle_new_item(item, feed) do
    attrs = %{
      "feed_id" => feed.id,
      "guid" => item["guid"],
      "title" => item["title"],
      "url" => item["url"],
      "description" => item["description"],
      "published_at" => item["published_at"],
      "research_status" => "pending"
    }

    case ArticleStore.create(attrs) do
      {:ok, article} ->
        Logger.debug("Stored article: #{article.title}")
        Publisher.publish_ingested(article, feed)

      {:error, reason} ->
        Logger.warning("Failed to store article: #{inspect(reason)}")
    end
  end

  defp update_error_count(feed_id) do
    with {:ok, feed} <- FeedStore.get(feed_id) |> elem(1),
         {:ok, updated} <- FeedStore.update(feed_id, %{"error_count" => feed.error_count + 1}) do
      Logger.info("Updated error count for feed #{feed_id}: #{updated.error_count}")
    else
      _ -> :ok
    end
  end
end

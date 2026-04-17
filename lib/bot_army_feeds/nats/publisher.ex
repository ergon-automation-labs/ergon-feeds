defmodule BotArmyFeeds.NATS.Publisher do
  @moduledoc """
  NATS publisher for bot_army_feeds events.
  """

  alias BotArmyRuntime.NATS.Publisher

  @doc """
  Publish article ingested event.
  """
  def publish_ingested(article, feed) do
    event = %{
      "event" => "events.feeds.article.ingested",
      "event_id" => UUID.uuid4() |> to_string(),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "source" => "bot_army_feeds",
      "payload" => %{
        "article_id" => article.id,
        "feed_id" => feed.id,
        "feed_name" => feed.name,
        "feed_category" => feed.category,
        "title" => article.title,
        "url" => article.url,
        "guid" => article.guid
      }
    }

    Publisher.publish("events.feeds.article.ingested", event)
  end

  @doc """
  Publish research complete event.
  """
  def publish_researched(article, research_notes, topics \\ []) do
    event = %{
      "event" => "events.feeds.article.researched",
      "event_id" => UUID.uuid4() |> to_string(),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "source" => "bot_army_feeds",
      "payload" => %{
        "article_id" => article.id,
        "title" => article.title,
        "url" => article.url,
        "research_status" => article.research_status,
        "research_notes" => research_notes,
        "topics" => topics
      }
    }

    Publisher.publish("events.feeds.article.researched", event)
  end

  @doc """
  Submit LLM request with a rendered prompt.
  """
  def submit_llm_request(prompt, skill_name, bot_id) do
    event = %{
      "event" => "llm.inference.chain",
      "event_id" => UUID.uuid4() |> to_string(),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "source" => "bot_army_feeds",
      "payload" => %{
        "chain" => [
          %{
            "name" => to_string(skill_name),
            "input" => prompt
          }
        ],
        "context" => %{
          "skill_name" => skill_name,
          "bot_id" => bot_id,
          "skill_type" => "markdown"
        }
      }
    }

    Publisher.publish("llm.inference.chain", event)
  end

  @doc """
  Publish topic discovered event.
  """
  def publish_topic_discovered(topic, article, feed) do
    event = %{
      "event" => "events.feeds.topic.discovered",
      "event_id" => UUID.uuid4() |> to_string(),
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "source" => "bot_army_feeds",
      "payload" => %{
        "topic" => topic,
        "article_id" => article.id,
        "article_title" => article.title,
        "article_url" => article.url,
        "feed_id" => feed.id,
        "feed_name" => feed.name,
        "feed_category" => feed.category,
        "feed_tags" => feed.tags
      }
    }

    Publisher.publish("events.feeds.topic.discovered", event)
  end
end

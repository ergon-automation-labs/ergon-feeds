defmodule BotArmyFeeds.Handlers.ResearchHandler do
  @moduledoc """
  Handler for article research using LLM.

  Uses bot_army_llm to extract topics, generate summaries, and identify
  interesting research angles from RSS feed articles.
  """

  alias BotArmyFeeds.Stores.{ArticleStore, FeedStore}
  alias BotArmyFeeds.NATS.Publisher

  @doc """
  Request research on an article.
  """
  def request_research(article_id) when is_binary(article_id) or is_atom(article_id) do
    case ArticleStore.get(article_id) do
      {:ok, article} ->
        case FeedStore.get(article.feed_id) do
          {:ok, feed} ->
            payload = %{
              "event" => "llm.inference.chain",
              "event_id" => UUID.uuid4() |> to_string(),
              "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
              "source" => "bot_army_feeds",
              "payload" => %{
                "chain" => [
                  %{
                    "name" => "extract_topics",
                    "input" => """
                    Analyze this article and extract key topics and technologies.
                    Return as JSON with: "topics" (array of strings), "technologies" (array), "domain" (string).

                    Title: #{article.title}
                    URL: #{article.url}
                    Description: #{article.description}
                    Content: #{String.slice(article.content, 0, 5000)}
                    """
                  },
                  %{
                    "name" => "generate_summary",
                    "input" => """
                    Generate a 2-3 sentence summary of this article.

                    Title: #{article.title}
                    URL: #{article.url}
                    Description: #{article.description}
                    Content: #{String.slice(article.content, 0, 10000)}
                    """
                  }
                ],
                "context" => %{
                  "article_id" => article_id,
                  "feed_id" => feed.id,
                  "feed_name" => feed.name,
                  "feed_category" => feed.category
                }
              }
            }

            BotArmyRuntime.NATS.Publisher.publish("llm.inference.chain", payload)
            ArticleStore.update_research_status(article_id, :processing, "")

          {:error, _} ->
            {:error, "Feed not found for article"}
        end

      {:error, :not_found} ->
        {:error, "Article not found"}

      error ->
        {:error, "Failed to get article: #{inspect(error)}"}
    end
  end

  @doc """
  Handle LLM research response.
  """
  def handle_research_response(message) do
    payload = message["payload"] || %{}

    article_id = payload["context"]["article_id"]
    feed_id = payload["context"]["feed_id"]
    feed_name = payload["context"]["feed_name"]
    feed_category = payload["context"]["feed_category"]

    research_notes = extract_research_notes(payload)
    topics = extract_topics(payload)

    case ArticleStore.update_research_status(article_id, :researched, research_notes) do
      {:ok, _article} ->
        Enum.each(topics, fn topic ->
          payload = %{
            "event" => "events.feeds.topic.discovered",
            "event_id" => UUID.uuid4() |> to_string(),
            "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
            "source" => "bot_army_feeds",
            "payload" => %{
              "topic" => topic,
              "article_id" => article_id,
              "article_title" => payload["context"]["article_title"],
              "url" => payload["context"]["url"],
              "feed_id" => feed_id,
              "feed_name" => feed_name,
              "feed_category" => feed_category
            }
          }

          BotArmyRuntime.NATS.Publisher.publish("events.feeds.topic.discovered", payload)
        end)

        Publisher.publish_researched(
          %{
            id: article_id,
            title: payload["context"]["article_title"],
            research_status: "researched"
          },
          research_notes,
          topics
        )

        {:ok, %{article_id: article_id, topics: topics, notes: research_notes}}

      error ->
        {:error, "Failed to update article: #{inspect(error)}"}
    end
  end

  defp extract_research_notes(payload) do
    chain_results = payload["chain_results"] || []
    summary = Enum.find(chain_results, &(&1["name"] == "generate_summary"))

    if summary && summary["output"] do
      "## Research Summary\n\n" <> summary["output"]
    else
      "Research completed but no summary available."
    end
  end

  defp extract_topics(payload) do
    chain_results = payload["chain_results"] || []
    extract = Enum.find(chain_results, &(&1["name"] == "extract_topics"))

    if extract && extract["output"] do
      case Jason.decode(extract["output"]) do
        {:ok, %{"topics" => topics}} when is_list(topics) ->
          topics

        _ ->
          extract_topics_from_text(extract["output"])
      end
    else
      []
    end
  end

  defp extract_topics_from_text(text) do
    text
    |> String.split(["\n", " ", "."])
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(String.length(&1) > 2))
    |> Enum.uniq()
    |> Enum.take(10)
  end
end

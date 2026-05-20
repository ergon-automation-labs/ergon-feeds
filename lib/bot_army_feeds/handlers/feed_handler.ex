defmodule BotArmyFeeds.Handlers.FeedHandler do
  @moduledoc """
  Handler for feed management requests via NATS request/reply.

  Provides a consistent interface for TUIs and other services to manage feeds.
  """

  alias BotArmyFeeds.Stores.FeedStore

  @doc """
  Handle list feeds request.
  """
  def handle_list_feeds do
    case FeedStore.list() do
      {:ok, feeds} ->
        {:ok,
         %{
           "ok" => true,
           "feeds" => Enum.map(feeds, &feed_to_map/1)
         }}

      error ->
        {:error, %{message: "Failed to list feeds", details: inspect(error)}}
    end
  end

  @doc """
  Handle add feed request.
  """
  def handle_add_feed(attrs) when is_map(attrs) do
    case FeedStore.create(attrs) do
      {:ok, feed} ->
        {:ok,
         %{
           "ok" => true,
           "feed_id" => feed.id,
           "message" => "Feed added successfully"
         }}

      {:error, changeset} ->
        {:error,
         %{
           "ok" => false,
           "message" => "Failed to add feed",
           "errors" => Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
         }}

      error ->
        {:error,
         %{
           "ok" => false,
           "message" => "Failed to add feed",
           "details" => inspect(error)
         }}
    end
  end

  @doc """
  Handle remove feed request.
  """
  def handle_remove_feed(feed_id) when is_binary(feed_id) or is_atom(feed_id) do
    case FeedStore.get(feed_id) do
      {:ok, feed} ->
        FeedStore.remove(feed_id)

        {:ok,
         %{
           "ok" => true,
           "message" => "Feed removed: #{feed.name}"
         }}

      {:error, :not_found} ->
        {:error,
         %{
           "ok" => false,
           "message" => "Feed not found"
         }}

      error ->
        {:error,
         %{
           "ok" => false,
           "message" => "Failed to remove feed",
           "details" => inspect(error)
         }}
    end
  end

  @doc """
  Handle update feed request.
  """
  def handle_update_feed(feed_id, attrs) when is_map(attrs) do
    case FeedStore.get(feed_id) do
      {:ok, _feed} ->
        case FeedStore.update(feed_id, attrs) do
          {:ok, updated} ->
            {:ok,
             %{
               "ok" => true,
               "feed" => feed_to_map(updated),
               "message" => "Feed updated"
             }}

          error ->
            {:error,
             %{
               "ok" => false,
               "message" => "Failed to update feed",
               "details" => inspect(error)
             }}
        end

      {:error, :not_found} ->
        {:error,
         %{
           "ok" => false,
           "message" => "Feed not found"
         }}

      error ->
        {:error,
         %{
           "ok" => false,
           "message" => "Failed to update feed",
           "details" => inspect(error)
         }}
    end
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

  defp translate_error({msg, opts}) do
    # Simplified - in production, use proper i18n
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "{#{key}}", to_string(value))
    end)
  end
end

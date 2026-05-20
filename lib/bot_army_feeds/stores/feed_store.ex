defmodule BotArmyFeeds.Stores.FeedStore do
  @moduledoc """
  GenServer store for RSS feeds.

  Manages feed configuration with in-memory caching and PostgreSQL persistence.

  ## Usage

      # List all feeds
      feeds = FeedStore.list()

      # Get a feed by ID
      {:ok, feed} = FeedStore.get(feed_id)

      # Add a new feed
      {:ok, feed} = FeedStore.create(%{
        "url" => "https://example.com/rss",
        "name" => "Example News",
        "category" => "news",
        "tags" => ["llm", "ai"]
      })

      # Update a feed
      {:ok, feed} = FeedStore.update(feed_id, %{"enabled" => false})

      # Remove a feed
      FeedStore.remove(feed_id)
  """

  use GenServer
  require Logger

  alias BotArmyFeeds.Repo
  alias BotArmyFeeds.Schemas.Feed

  @doc false
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  List all configured feeds.
  """
  def list, do: GenServer.call(__MODULE__, :list)

  @doc """
  Get a feed by ID.
  """
  def get(feed_id), do: GenServer.call(__MODULE__, {:get, feed_id})

  @doc """
  Add a new feed.
  """
  def create(attrs), do: GenServer.call(__MODULE__, {:create, attrs})

  @doc """
  Update an existing feed.
  """
  def update(feed_id, attrs), do: GenServer.call(__MODULE__, {:update, feed_id, attrs})

  @doc """
  Remove a feed.
  """
  def remove(feed_id), do: GenServer.call(__MODULE__, {:remove, feed_id})

  @doc """
  Get feed by URL.
  """
  def get_by_url(url), do: GenServer.call(__MODULE__, {:get_by_url, url})

  @doc """
  Enable a feed.
  """
  def enable(feed_id), do: GenServer.call(__MODULE__, {:enable, feed_id})

  @doc """
  Disable a feed.
  """
  def disable(feed_id), do: GenServer.call(__MODULE__, {:disable, feed_id})

  # GenServer callbacks

  @impl true
  def init(_opts) do
    Logger.info("FeedStore starting...")
    feeds = load_all()
    Logger.info("Loaded #{length(feeds)} feed(s)")
    {:ok, %{feeds: feeds}}
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, {:ok, Map.values(state.feeds)}, state}
  end

  def handle_call({:get, feed_id}, _from, state) do
    case Map.get(state.feeds, feed_id) do
      nil -> {:reply, {:error, :not_found}, state}
      feed -> {:reply, {:ok, feed}, state}
    end
  end

  def handle_call({:get_by_url, url}, _from, state) do
    feed = Enum.find(Map.values(state.feeds), &(Map.get(&1, :url) == url))

    case feed do
      nil -> {:reply, {:error, :not_found}, state}
      feed -> {:reply, {:ok, feed}, state}
    end
  end

  def handle_call({:create, attrs}, _from, state) do
    case insert_feed(attrs) do
      {:ok, feed} ->
        new_state = %{state | feeds: Map.put(state.feeds, feed.id, feed)}
        {:reply, {:ok, feed}, new_state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:update, feed_id, attrs}, _from, state) do
    case Map.get(state.feeds, feed_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      _ ->
        case update_feed(feed_id, attrs) do
          {:ok, feed} ->
            new_state = %{state | feeds: Map.put(state.feeds, feed_id, feed)}
            {:reply, {:ok, feed}, new_state}

          error ->
            {:reply, error, state}
        end
    end
  end

  def handle_call({:remove, feed_id}, _from, state) do
    case Map.get(state.feeds, feed_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      _ ->
        Repo.delete!(Repo.get(Feed, feed_id))
        new_state = %{state | feeds: Map.delete(state.feeds, feed_id)}
        {:reply, :ok, new_state}
    end
  end

  def handle_call({:enable, feed_id}, _from, state) do
    update_status(feed_id, true, state)
  end

  def handle_call({:disable, feed_id}, _from, state) do
    update_status(feed_id, false, state)
  end

  # Internal functions

  defp update_status(feed_id, status, state) do
    case Map.get(state.feeds, feed_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      _feed ->
        case Feed
             |> Ecto.Changeset.change(%{enabled: status})
             |> Repo.update() do
          {:ok, updated_feed} ->
            new_state = %{state | feeds: Map.put(state.feeds, feed_id, updated_feed)}
            {:reply, {:ok, updated_feed}, new_state}

          error ->
            {:reply, error, state}
        end
    end
  end

  defp load_all do
    feeds =
      Repo.all(Feed)
      |> Enum.reduce(%{}, fn feed, acc ->
        Map.put(acc, feed.id, feed)
      end)

    # Load related articles count for each feed
    feeds_with_count =
      feeds
      |> Enum.map(fn {id, feed} ->
        article_count = Repo.aggregate(Feed, :count, :id, feed_id: feed.id)
        {id, Map.put(feed, :article_count, article_count)}
      end)
      |> Enum.into(%{})

    feeds_with_count
  end

  defp insert_feed(attrs) do
    Feed.changeset(%Feed{}, attrs) |> Repo.insert()
  end

  defp update_feed(feed_id, attrs) do
    with {:ok, feed} <- Repo.get(Feed, feed_id) do
      Feed.changeset(feed, attrs) |> Repo.update()
    end
  end
end

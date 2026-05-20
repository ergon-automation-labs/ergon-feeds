defmodule BotArmyFeeds.Stores.ArticleStore do
  @moduledoc """
  GenServer store for RSS articles.

  Manages parsed articles with in-memory caching and PostgreSQL persistence.

  ## Usage

      # List all articles (optionally filtered by feed_id)
      {:ok, articles} = ArticleStore.list(feed_id)

      # Get an article by ID
      {:ok, article} = ArticleStore.get(article_id)

      # Create a new article
      {:ok, article} = ArticleStore.create(%{
        "feed_id" => feed_id,
        "guid" => "unique-guid",
        "title" => "Article Title",
        "url" => "https://example.com/article",
        "description" => "Short description",
        "published_at" => "2024-01-01T00:00:00Z"
      })

      # Update research status
      {:ok, article} = ArticleStore.update_research_status(article_id, :researched, notes)

      # Get articles needing research
      {:ok, pending} = ArticleStore.list_needing_research()
  """

  use GenServer
  require Logger

  alias BotArmyFeeds.Repo
  alias BotArmyFeeds.Schemas.Article

  @doc false
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  List articles, optionally filtered by feed_id.
  """
  def list(feed_id \\ nil), do: GenServer.call(__MODULE__, {:list, feed_id})

  @doc """
  Get an article by ID.
  """
  def get(article_id), do: GenServer.call(__MODULE__, {:get, article_id})

  @doc """
  Create a new article.
  """
  def create(attrs), do: GenServer.call(__MODULE__, {:create, attrs})

  @doc """
  Update an article.
  """
  def update(article_id, attrs), do: GenServer.call(__MODULE__, {:update, article_id, attrs})

  @doc """
  Update research status and notes.
  """
  def update_research_status(article_id, status, notes \\ ""),
    do: GenServer.call(__MODULE__, {:update_research_status, article_id, status, notes})

  @doc """
  Get articles that need research (status: :pending or :processing).
  """
  def list_needing_research, do: GenServer.call(__MODULE__, :list_needing_research)

  @doc """
  List recent articles (last N hours, up to limit).
  """
  def list_recent(hours \\ 48, limit \\ 20),
    do: GenServer.call(__MODULE__, {:list_recent, hours, limit})

  @doc """
  Mark an article as seen by GUID (returns :ok or :error if already exists).
  """
  def mark_seen(feed_id, guid), do: GenServer.call(__MODULE__, {:mark_seen, feed_id, guid})

  # GenServer callbacks

  @impl true
  def init(_opts) do
    Logger.info("ArticleStore starting...")
    articles = load_all()
    Logger.info("Loaded #{length(articles)} article(s)")
    {:ok, %{articles: articles}}
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, {:ok, Map.values(state.articles)}, state}
  end

  def handle_call({:list, feed_id}, _from, state) do
    articles =
      state.articles
      |> Enum.filter(&(Map.get(&1, :feed_id) == feed_id))

    {:reply, {:ok, articles}, state}
  end

  def handle_call({:get, article_id}, _from, state) do
    case Map.get(state.articles, article_id) do
      nil -> {:reply, {:error, :not_found}, state}
      article -> {:reply, {:ok, article}, state}
    end
  end

  def handle_call({:create, attrs}, _from, state) do
    case insert_article(attrs) do
      {:ok, article} ->
        new_state = %{state | articles: Map.put(state.articles, article.id, article)}
        {:reply, {:ok, article}, new_state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:update, article_id, attrs}, _from, state) do
    case Map.get(state.articles, article_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      _ ->
        case update_article(article_id, attrs) do
          {:ok, article} ->
            new_state = %{state | articles: Map.put(state.articles, article_id, article)}
            {:reply, {:ok, article}, new_state}

          error ->
            {:reply, error, state}
        end
    end
  end

  def handle_call({:update_research_status, article_id, status, notes}, _from, state) do
    case Map.get(state.articles, article_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      _ ->
        case Article
             |> Ecto.Changeset.change(%{
               research_status: status,
               research_notes: notes
             })
             |> Repo.update() do
          {:ok, article} ->
            new_state = %{state | articles: Map.put(state.articles, article_id, article)}
            {:reply, {:ok, article}, new_state}

          error ->
            {:reply, error, state}
        end
    end
  end

  def handle_call(:list_needing_research, _from, state) do
    articles =
      state.articles
      |> Enum.filter(&(Map.get(&1, :research_status) in [:pending, :processing]))

    {:reply, {:ok, articles}, state}
  end

  def handle_call({:list_recent, hours, limit}, _from, state) do
    cutoff = DateTime.add(DateTime.utc_now(), -hours, :hour)

    articles =
      state.articles
      |> Enum.sort_by(&Map.get(&1, :inserted_at), {:desc, DateTime})
      |> Enum.filter(fn article ->
        inserted_at = Map.get(article, :inserted_at)
        is_struct(inserted_at, DateTime) and DateTime.compare(inserted_at, cutoff) != :lt
      end)
      |> Enum.take(limit)

    {:reply, {:ok, articles}, state}
  end

  def handle_call({:mark_seen, feed_id, guid}, _from, state) do
    existing =
      state.articles
      |> Enum.find(&(Map.get(&1, :feed_id) == feed_id and Map.get(&1, :guid) == guid))

    case existing do
      nil ->
        # Not seen yet - will be created by poller
        {:reply, :ok, state}

      _ ->
        # Already exists - return error to signal skip
        {:reply, {:error, :already_exists}, state}
    end
  end

  # Internal functions

  defp load_all do
    articles =
      Repo.all(Article)
      |> Enum.reduce(%{}, fn article, acc ->
        Map.put(acc, article.id, article)
      end)

    articles
  end

  defp insert_article(attrs) do
    Article.changeset(%Article{}, attrs) |> Repo.insert()
  end

  defp update_article(article_id, attrs) do
    with {:ok, article} <- Repo.get(Article, article_id) do
      Article.changeset(article, attrs) |> Repo.update()
    end
  end
end

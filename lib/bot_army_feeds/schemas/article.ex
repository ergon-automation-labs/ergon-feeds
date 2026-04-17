defmodule BotArmyFeeds.Schemas.Article do
  @moduledoc """
  Article schema for RSS feed items.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "articles" do
    field(:feed_id, Ecto.UUID)
    field(:guid, :string)
    field(:title, :string)
    field(:url, :string)
    field(:description, :string)
    field(:content, :string)
    field(:published_at, :string)
    field(:research_status, :string, default: "pending")
    field(:research_notes, :string, default: "")

    timestamps()
  end

  @doc false
  def changeset(article, attrs) do
    article
    |> cast(attrs, [:feed_id, :guid, :title, :url, :description, :content, :published_at])
    |> validate_required([:feed_id, :guid, :title, :url])
    |> validate_length(:title, min: 1, max: 500)
    |> validate_length(:description, max: 2000)
    |> validate_length(:content, max: 50_000)
    |> unique_constraint(:guid, name: :articles_feed_id_guid_index)
  end
end

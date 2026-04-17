defmodule BotArmyFeeds.Schemas.Feed do
  @moduledoc """
  Feed schema for RSS feed configuration.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "feeds" do
    field(:url, :string)
    field(:name, :string)
    field(:category, :string)
    field(:tags, {:array, :string})
    field(:enabled, :boolean, default: true)
    field(:last_polled, :utc_datetime)
    field(:error_count, :integer, default: 0)

    timestamps()
  end

  @doc false
  def changeset(feed, attrs) do
    feed
    |> cast(attrs, [:url, :name, :category, :tags, :enabled])
    |> validate_required([:url, :name])
    |> validate_url()
    |> validate_length(:name, min: 1, max: 200)
    |> validate_length(:category, min: 1, max: 50)
    |> unique_constraint(:url)
  end

  defp validate_url(changeset) do
    case get_change(changeset, :url) do
      nil ->
        changeset

      url ->
        if Regex.match?(~r/^https?:\/\/.+/i, url) do
          changeset
        else
          add_error(changeset, :url, "must be a valid URL with http:// or https://")
        end
    end
  end
end

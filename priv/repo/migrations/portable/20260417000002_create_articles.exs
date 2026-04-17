defmodule BotArmyFeeds.Repo.Migrations.CreateArticles do
  use Ecto.Migration

  def change do
    create table(:articles) do
      add(:feed_id, :uuid, null: false)
      add(:guid, :string, null: false)
      add(:title, :string, null: false)
      add(:url, :string, null: false)
      add(:description, :text)
      add(:content, :text)
      add(:published_at, :string)
      add(:research_status, :string, default: "pending")
      add(:research_notes, :text, default: "")

      timestamps()
    end

    create(index(:articles, [:feed_id]))
    create(index(:articles, [:guid]))
    create(unique_index(:articles, [:feed_id, :guid], name: :articles_feed_id_guid_index))
  end
end

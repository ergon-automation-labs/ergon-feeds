defmodule BotArmyFeeds.Repo.Migrations.CreateFeeds do
  use Ecto.Migration

  def change do
    create table(:feeds) do
      add(:url, :string, null: false)
      add(:name, :string, null: false)
      add(:category, :string)
      add(:tags, :text)
      add(:enabled, :boolean, default: true, null: false)
      add(:last_polled, :datetime)
      add(:error_count, :integer, default: 0, null: false)

      timestamps()
    end

    create(unique_index(:feeds, [:url]))
  end
end

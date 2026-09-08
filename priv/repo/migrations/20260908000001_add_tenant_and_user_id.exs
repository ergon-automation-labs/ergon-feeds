defmodule BotArmyFeeds.Repo.Migrations.AddTenantAndUserId do
  use Ecto.Migration

  def up do
    default_tenant_id = "00000000-0000-0000-0000-000000000001"

    # Add tenant_id and user_id to feeds (idempotent)
    unless Ecto.Migration.column_exists?(:feeds, :tenant_id) do
      alter table(:feeds) do
        add(:tenant_id, :uuid, null: true)
        add(:user_id, :uuid, null: true)
      end

      create(index(:feeds, [:tenant_id]))
      create(index(:feeds, [:user_id]))

      execute(
        "UPDATE feeds SET tenant_id = '#{default_tenant_id}'::uuid WHERE tenant_id IS NULL"
      )
    end

    # Add tenant_id and user_id to articles (idempotent)
    unless Ecto.Migration.column_exists?(:articles, :tenant_id) do
      alter table(:articles) do
        add(:tenant_id, :uuid, null: true)
        add(:user_id, :uuid, null: true)
      end

      create(index(:articles, [:tenant_id]))
      create(index(:articles, [:user_id]))

      execute(
        "UPDATE articles SET tenant_id = '#{default_tenant_id}'::uuid WHERE tenant_id IS NULL"
      )
    end
  end

  def down do
    for table <- [:feeds, :articles] do
      if Ecto.Migration.index_exists?(table, [:tenant_id]) do
        drop(index(table, [:tenant_id]))
      end

      if Ecto.Migration.index_exists?(table, [:user_id]) do
        drop(index(table, [:user_id]))
      end

      if Ecto.Migration.column_exists?(table, :tenant_id) do
        alter table(table) do
          remove(:tenant_id)
          remove(:user_id)
        end
      end
    end
  end
end

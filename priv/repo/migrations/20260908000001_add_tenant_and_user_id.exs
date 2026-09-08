defmodule BotArmyFeeds.Repo.Migrations.AddTenantAndUserId do
  @moduledoc """
  Adds tenant_id/user_id to feeds and articles.

  Unconditional (no column_exists?/index_exists? guards): Ecto.Migration
  has no such introspection functions in the pinned ecto 3.13.x — the
  guards were undefined at runtime (RERUN13, 2026-09-08). Idempotency is
  provided by Ecto's own schema_migrations bookkeeping instead.
  """

  use Ecto.Migration

  @default_tenant_id "00000000-0000-0000-0000-000000000001"

  def up do
    alter table(:feeds) do
      add(:tenant_id, :uuid, null: true)
      add(:user_id, :uuid, null: true)
    end

    create(index(:feeds, [:tenant_id]))
    create(index(:feeds, [:user_id]))

    execute(
      "UPDATE feeds SET tenant_id = '#{@default_tenant_id}'::uuid WHERE tenant_id IS NULL"
    )

    alter table(:articles) do
      add(:tenant_id, :uuid, null: true)
      add(:user_id, :uuid, null: true)
    end

    create(index(:articles, [:tenant_id]))
    create(index(:articles, [:user_id]))

    execute(
      "UPDATE articles SET tenant_id = '#{@default_tenant_id}'::uuid WHERE tenant_id IS NULL"
    )
  end

  def down do
    for table <- [:feeds, :articles] do
      drop(index(table, [:tenant_id]))
      drop(index(table, [:user_id]))

      alter table(table) do
        remove(:tenant_id)
        remove(:user_id)
      end
    end
  end
end
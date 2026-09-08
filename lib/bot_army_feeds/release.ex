defmodule BotArmyFeeds.Release do
  @moduledoc false

  alias BotArmyLibraryRuntime.Ecto.MigrationRunner

  @app :bot_army_feeds

  def migrate do
    MigrationRunner.run(
      repo_module: BotArmyFeeds.Repo,
      app_module: @app
    )
  end

  def rollback(repo, version) do
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end
end
defmodule BotArmyFeeds.GenBotInstance do
  @moduledoc """
  Concrete GenBot instance for bot_army_feeds.

  `BotArmyFeeds.GenBot` is a `__using__` macro module — it cannot itself be a
  supervisor child (no child_spec/1; phase-04 pack matrix crash:
  "The module BotArmyFeeds.GenBot was given as a child to a supervisor but it
  does not implement child_spec/1", feeds_bot restart-looping in the
  core-research / core-full combos, 2026-09-08). `use` it here so the
  generated GenServer + child_spec/1 land on this module, then add this
  module as the supervisor child (application.ex).

  Skills are markdown files under `skills/` (see the GenBot moduledoc for
  the frontmatter format).
  """

  use BotArmyFeeds.GenBot,
    bot_id: :feeds,
    skills_dir: "skills/",
    jobs_dir: "jobs/"
end
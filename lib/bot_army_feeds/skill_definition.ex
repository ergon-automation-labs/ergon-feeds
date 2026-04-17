defmodule BotArmyFeeds.SkillDefinition do
  @moduledoc """
  Represents a markdown skill definition.
  """

  @type t :: %__MODULE__{
          name: atom(),
          description: String.t(),
          triggers: [String.t()],
          template: String.t(),
          source_file: String.t()
        }

  defstruct [:name, :description, :triggers, :template, :source_file]
end

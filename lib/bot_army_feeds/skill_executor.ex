defmodule BotArmyFeeds.SkillExecutor do
  @moduledoc """
  Executes a skill by rendering its template and submitting the prompt to the LLM.
  """

  require Logger

  alias BotArmyFeeds.SkillDefinition
  alias BotArmyFeeds.NATS.Publisher

  @spec render_template(template :: String.t(), payload :: map()) :: String.t()
  def render_template(template, payload) when is_binary(template) and is_map(payload) do
    Regex.replace(~r/\{\{\s*payload\.([a-zA-Z0-9_.]+)\s*\}\}/, template, fn _match, path ->
      path
      |> String.split(".")
      |> resolve_path(payload)
    end)
  end

  @spec execute(skill :: SkillDefinition.t(), payload :: map(), bot_id :: atom()) ::
          :ok | {:error, term()}
  def execute(%SkillDefinition{} = skill, payload, bot_id)
      when is_map(payload) and is_atom(bot_id) do
    rendered_prompt = render_template(skill.template, payload)
    Publisher.submit_llm_request(rendered_prompt, skill.name, bot_id)
  end

  defp resolve_path(path_parts, payload) do
    try do
      case get_in(payload, path_parts) do
        nil -> ""
        value when is_binary(value) -> value
        value -> inspect(value)
      end
    rescue
      _ -> ""
    end
  end
end

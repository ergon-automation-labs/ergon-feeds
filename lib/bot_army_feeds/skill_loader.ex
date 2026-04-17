defmodule BotArmyFeeds.SkillLoader do
  @moduledoc """
  Loads skill and job definitions from markdown files.

  Files are expected to have YAML frontmatter (between `---` delimiters) containing:
    - name: (required) atom identifier
    - description: (required) human-readable description
    - triggers: (required for skills) list of NATS subject strings

  The body after the second `---` is treated as the prompt template.
  """

  alias BotArmyFeeds.SkillDefinition
  require Logger

  @spec load_all(dir :: String.t()) :: [SkillDefinition.t()]
  def load_all(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".md"))
        |> Enum.map(&Path.join(dir, &1))
        |> Enum.flat_map(&load_file_safe/1)

      {:error, _} ->
        Logger.debug("Skill directory not found: #{dir}")
        []
    end
  end

  @spec load_file(path :: String.t()) :: {:ok, SkillDefinition.t()} | {:error, term()}
  def load_file(path) do
    with {:ok, content} <- File.read(path),
         {:ok, skill_def} <- parse_markdown(content, path) do
      {:ok, skill_def}
    else
      error -> error
    end
  end

  defp load_file_safe(path) do
    case load_file(path) do
      {:ok, skill_def} ->
        [skill_def]

      {:error, reason} ->
        Logger.warning("Failed to load skill from #{path}: #{inspect(reason)}")
        []
    end
  end

  defp parse_markdown(content, path) do
    case String.split(content, "---", parts: 3) do
      ["", frontmatter, body] ->
        with {:ok, attrs} <- parse_frontmatter(frontmatter),
             :ok <- validate_required_fields(attrs),
             skill_def <- build_skill_definition(attrs, String.trim(body), path) do
          {:ok, skill_def}
        end

      _ ->
        {:error, "Markdown file must start with --- and have a second --- separator"}
    end
  end

  defp parse_frontmatter(frontmatter_text) do
    lines = String.split(frontmatter_text, "\n")

    attrs =
      lines
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.reduce(%{}, fn line, acc ->
        case parse_frontmatter_line(line) do
          {key, value} -> Map.put(acc, key, value)
          nil -> acc
        end
      end)

    {:ok, attrs}
  end

  defp parse_frontmatter_line(line) do
    case String.split(line, ":", parts: 2) do
      [key, value] ->
        key_atom = String.trim(key) |> String.to_atom()
        value_str = String.trim(value)
        parse_frontmatter_value(key_atom, value_str)

      _ ->
        nil
    end
  end

  defp parse_frontmatter_value(:name, value) do
    {:name, String.to_atom(value)}
  end

  defp parse_frontmatter_value(:description, value) do
    {:description, value}
  end

  defp parse_frontmatter_value(:triggers, value) do
    {:triggers, [value]}
  end

  defp parse_frontmatter_value(_key, _value) do
    nil
  end

  defp validate_required_fields(attrs) do
    required = [:name, :description, :triggers]

    case Enum.find(required, &(not Map.has_key?(attrs, &1))) do
      nil -> :ok
      missing_field -> {:error, "Missing required field: #{missing_field}"}
    end
  end

  defp build_skill_definition(attrs, template, path) do
    %SkillDefinition{
      name: Map.get(attrs, :name),
      description: Map.get(attrs, :description),
      triggers: Map.get(attrs, :triggers, []),
      template: template,
      source_file: path
    }
  end
end

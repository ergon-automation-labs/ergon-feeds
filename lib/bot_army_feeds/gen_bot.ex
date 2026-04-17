defmodule BotArmyFeeds.GenBot do
  @moduledoc """
  Markdown-driven GenBot for bot_army_feeds.

  Allows defining skills as markdown files that process RSS feed articles.

  ## Usage

  Add to your application:

  ```elixir
  children = [
    {BotArmyFeeds.GenBot,
      [
        bot_id: :feeds,
        skills_dir: "skills/",
        jobs_dir: "jobs/"
      ]}
  ]
  ```

  ## Markdown Skill Format

  Skills are `.md` files in the skills/ directory with YAML frontmatter:

  ```markdown
  ---
  name: summarize_article
  description: Generate a summary of RSS feed articles
  triggers:
    - events.feeds.article.ingested
  ---
  You are a helpful assistant that summarizes news articles.

  ## Article to Summarize

  **Title:** {{ payload.title }}
  **URL:** {{ payload.url }}
  **Feed:** {{ payload.feed_name }}

  {{ payload.content }}

  ## Instructions

  Provide a 2-3 sentence summary of the article content.
  """
  require Logger

  defmacro __using__(opts) do
    bot_id = Keyword.fetch!(opts, :bot_id)
    skills_dir = Keyword.get(opts, :skills_dir, "skills/")
    jobs_dir = Keyword.get(opts, :jobs_dir, "jobs/")

    quote do
      use GenServer

      require Logger

      alias BotArmyFeeds.{SkillLoader, SkillExecutor}

      @bot_id unquote(bot_id)
      @skills_dir unquote(skills_dir)
      @jobs_dir unquote(jobs_dir)

      def start_link(init_arg) do
        GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
      end

      def init(_init_arg) do
        Logger.info("[#{@bot_id}] Starting GenBot",
          bot_id: @bot_id,
          skills_dir: @skills_dir,
          jobs_dir: @jobs_dir
        )

        skills = load_all_skills()

        state = %{
          bot_id: @bot_id,
          skills: skills,
          trigger_index: build_trigger_index(skills),
          subscriptions: [],
          conn: nil
        }

        {:ok, state, {:continue, :connect}}
      end

      def handle_continue(:connect, state) do
        try do
          result = GenServer.call(BotArmyRuntime.NATS.Connection, :get_connection, 5000)

          case result do
            {:ok, conn} ->
              Logger.info("[#{@bot_id}] Connected to NATS")
              {:noreply, subscribe_to_triggers(state, conn)}

            {:error, reason} ->
              Logger.warning("[#{@bot_id}] Failed to get connection: #{inspect(reason)}")
              Process.send_after(self(), :connect_retry, 1000)
              {:noreply, state}
          end
        rescue
          e ->
            Logger.warning("[#{@bot_id}] Error getting NATS connection: #{Exception.message(e)}")
            Process.send_after(self(), :connect_retry, 1000)
            {:noreply, state}
        end
      end

      def handle_info({:msg, %{topic: topic, body: body}}, state) do
        try do
          payload = Jason.decode!(body)
          matching_skills = find_matching_skills(topic, state.trigger_index)

          Enum.each(matching_skills, fn skill ->
            Task.start(fn ->
              SkillExecutor.execute(skill, payload, state.bot_id)
            end)
          end)
        rescue
          e ->
            Logger.error(
              "[#{@bot_id}] Error processing message from #{topic}: #{Exception.message(e)}"
            )
        end

        {:noreply, state}
      end

      def handle_info(:connect_retry, state) do
        Logger.debug("[#{@bot_id}] Retrying NATS connection")
        {:noreply, state, {:continue, :connect}}
      end

      def handle_call({:get_skills}, _from, state) do
        {:reply, state.skills, state}
      end

      defp load_all_skills do
        skills_from_skills = SkillLoader.load_all(@skills_dir)
        skills_from_jobs = SkillLoader.load_all(@jobs_dir)
        skills_from_skills ++ skills_from_jobs
      end

      defp build_trigger_index(skills) do
        Enum.reduce(skills, %{}, fn skill, acc ->
          Enum.reduce(skill.triggers, acc, fn trigger, acc2 ->
            Map.put(acc2, trigger, skill)
          end)
        end)
      end

      defp subscribe_to_triggers(state, conn) do
        subscriptions =
          state.trigger_index
          |> Map.keys()
          |> Enum.map(fn trigger ->
            {:ok, sid} = Gnat.sub(conn, self(), trigger)
            {trigger, sid}
          end)

        Logger.info("[#{@bot_id}] Subscribed to #{Enum.count(subscriptions)} triggers")

        %{state | conn: conn, subscriptions: subscriptions}
      end

      defp find_matching_skills(topic, trigger_index) do
        case Map.get(trigger_index, topic) do
          nil -> []
          skill -> [skill]
        end
      end
    end
  end
end

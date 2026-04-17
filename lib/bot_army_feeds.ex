defmodule BotArmyFeeds do
  @moduledoc """
  bot_army_feeds - Generic RSS Feed Bot with Dynamic Management and Markdown Skills.

  A flexible RSS feed polling bot that supports:
  - Multiple RSS/Atom feeds from any source
  - Dynamic feed management via NATS (add/remove/list)
  - LLM-powered topic research and extraction
  - Markdown-driven skills for flexible content processing

  ## NATS Subjects

  ### Inbound (requests/commands)
  - `feeds.feed.add` - Add a new feed to monitor
  - `feeds.feed.remove` - Remove a feed by URL
  - `feeds.feed.update` - Update existing feed config
  - `feeds.feed.list` - List all configured feeds (request/reply)
  - `feeds.poll` - Trigger immediate poll of all feeds

  ### Outbound (events)
  - `events.feeds.article.ingested` - Article parsed from RSS
  - `events.feeds.article.researched` - Research complete on article
  - `events.feeds.topic.discovered` - Interesting topic found in article

  ## Markdown Skills

  Skills are defined as markdown files in the `skills/` directory:

  ```markdown
  ---
  name: skill_name
  description: What the skill does
  triggers:
    - events.feeds.article.ingested
  ---
  LLM prompt template with {{ payload.key }} variables.
  ```

  Available triggers:
  - `events.feeds.article.ingested` - When article is parsed from RSS
  - `events.feeds.topic.discovered` - When a topic is identified

  The GenBot automatically loads all skills from `skills/` and `jobs/` directories
  and subscribes to their trigger subjects.

  ## Database

  ### feeds table
  - `url` - RSS feed URL
  - `name` - Human-readable display name
  - `category` - news, tech, ai, job, etc.
  - `tags` - Array of interest tags
  - `enabled` - Toggle monitoring on/off
  - `last_polled` - When feed was last successfully polled
  - `error_count` - Track consecutive failures

  ### articles table
  - `feed_id` - FK to feeds
  - `guid` - Unique ID from RSS
  - `title`, `url`, `description`, `published_at`
  - `content` - Full article content (optional)
  - `research_status` - pending, processing, researched, skipped
  - `research_notes` - LLM-generated summary and topics

  ## Development

  ```bash
  mix deps.get
  mix test
  ```

  ## Deployment

  ```bash
  cd ../bot_army_infra
  make deploy-bot BOT=feeds
  ```

  Requires:
  1. PostgreSQL database configured
  2. RSS feed list in Salt pillar (or add via NATS)
  3. LLM bot available for topic research
  """

  @version "0.1.0"

  def version, do: @version
end

# bot_army_feeds

Generic RSS Feed Bot with Dynamic Management, Topic Research, and Markdown Skills.

## Features

- **Multiple RSS/Atom feeds** - Poll any RSS feed (news, blogs, AI sites, etc.)
- **Dynamic feed management** - Add/remove/update feeds via NATS
- **Article storage** - Persist parsed articles with PostgreSQL
- **Topic research** - LLM extracts topics for deeper analysis
- **Event-driven** - Publishes events for downstream processing
- **Markdown skills** - Define LLM skills as markdown files with YAML frontmatter

## Markdown Skills

Skills are defined as markdown files in the `skills/` directory:

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

{{ payload.content }}

## Instructions

Provide a 2-3 sentence summary of the article content.
```

Available triggers:
- `events.feeds.article.ingested` - When article is parsed from RSS
- `events.feeds.topic.discovered` - When a topic is identified

Template variables: `{{ payload.title }}`, `{{ payload.url }}`, `{{ payload.feed_name }}`, `{{ payload.feed_category }}`, `{{ payload.content }}`

See `skills/` directory for examples.

## Development

```bash
cd bot_army_feeds
mix deps.get
mix test
```

## Make Targets

```bash
make help              # Show all targets
make setup             # Setup deps + db
make test              # Run tests
make add-feed          # Add a feed via NATS
make remove-feed       # Remove a feed via NATS
make list-feeds        # List feeds via NATS
make poll-feeds        # Trigger immediate poll
```

## Deployment

```bash
cd ../bot_army_infra
make deploy-bot BOT=feeds
```

## Database

### feeds table
- `url` - RSS feed URL
- `name` - Human-readable display name
- `category` - news, tech, ai, job, etc.
- `tags` - Array of interest tags
- `enabled` - Toggle monitoring on/off
- `last_polled` - When feed was last polled
- `error_count` - Track consecutive failures

### articles table
- `feed_id` - FK to feeds
- `guid` - Unique ID from RSS
- `title`, `url`, `description`, `published_at`
- `content` - Full article content (optional)
- `research_status` - pending, processing, researched, skipped
- `research_notes` - LLM-generated summary and topics

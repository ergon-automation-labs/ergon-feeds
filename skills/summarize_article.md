---
name: summarize_article
description: Generate a summary of RSS feed articles
triggers:
  - events.feeds.article.ingested
---
You are a helpful assistant that summarizes news articles for the user.

## Article to Summarize

**Title:** {{ payload.title }}
**URL:** {{ payload.url }}
**Feed:** {{ payload.feed_name }}
**Category:** {{ payload.feed_category }}

{{ payload.content }}

## Instructions

Provide a 2-3 sentence summary of the article content. Focus on the main points and any actionable information.

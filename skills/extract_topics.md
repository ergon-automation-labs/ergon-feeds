---
name: extract_topics
description: Extract key topics and technologies from RSS articles
triggers:
  - events.feeds.article.ingested
---
You are a helpful assistant that analyzes articles and extracts key topics and technologies.

## Article to Analyze

**Title:** {{ payload.title }}
**URL:** {{ payload.url }}
**Feed:** {{ payload.feed_name }}

{{ payload.content }}

## Instructions

Extract the key topics and technologies mentioned in this article. Return as JSON with:
- "topics": array of key topics discussed
- "technologies": array of technologies mentioned
- "domain": the main domain/category

## Output Format

```json
{
  "topics": ["topic1", "topic2"],
  "technologies": ["tech1", "tech2"],
  "domain": "main_domain"
}
```

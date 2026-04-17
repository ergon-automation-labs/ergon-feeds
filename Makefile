SCRIPTS_DIRECTORY ?= $(abspath $(CURDIR)/../scripts)

.PHONY: setup help deps test credo dialyzer coverage check format clean release publish-release setup-hooks setup-db reset-db logs feeds

help:
	@echo "bot_army_feeds"
	@echo ""
	@echo "Setup commands:"
	@echo "  make setup           - Set up project (deps.get + install git hooks + setup database)"
	@echo "  make setup-hooks     - Install git hooks for pre-push validation"
	@echo "  make setup-db        - Create and migrate test database (required for testing)"
	@echo "  make reset-db        - Drop and recreate test database (useful for troubleshooting)"
	@echo ""
	@echo "Development commands:"
	@echo "  make test            - Run all tests"
	@echo "  make credo           - Run linter"
	@echo "  make dialyzer        - Run static analysis"
	@echo "  make coverage        - Run tests with coverage"
	@echo "  make check           - Run all checks (test, credo, dialyzer)"
	@echo "  make format          - Format Elixir code"
	@echo "  make clean           - Clean build artifacts"
	@echo ""
	@echo "Operations (deployed server logs):"
	@echo "  make logs            - Tail server log with grc"
	@echo ""
	@echo "Feed management (via NATS request/reply):"
	@echo "  make list-feeds      - List all configured feeds"
	@echo "  make add-feed URL=... NAME=... CAT=... TAGS=... - Add a new feed"
	@echo "  make remove-feed URL=... - Remove a feed"
	@echo "  make poll-feeds      - Trigger immediate feed poll"
	@echo ""
	@echo "Release commands (normally automatic via git hook):"
	@echo "  make release         - Build OTP release locally (manual, if needed)"
	@echo "  make publish-release - Build, package, and publish to GitHub (manual, if needed)"
	@echo ""
	@echo "Normal workflow:"
	@echo "  git push             - Pre-push hook validates, builds, and publishes automatically"

setup: init deps setup-hooks setup-db
	@echo "✓ Setup complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Configure .env with your database settings (if needed)"
	@echo "  2. Run: make test"
	@echo "  3. Start developing!"
	@echo ""

setup-hooks:
	@git config core.hooksPath git-hooks
	@echo "✓ Git hooks installed (core.hooksPath = git-hooks)"

setup-db:
	@echo "Setting up test database..."
	@MIX_ENV=test mix ecto.create || true
	@MIX_ENV=test mix ecto.migrate
	@echo "✓ Test database created and migrations applied"

reset-db:
	@echo "⚠️  Resetting test database (dropping and recreating)..."
	@MIX_ENV=test mix ecto.drop || true
	@MIX_ENV=test mix ecto.create
	@MIX_ENV=test mix ecto.migrate
	@echo "✓ Test database reset complete"

init:
	@if [ ! -d .git ]; then git init; echo "Git initialized."; else echo "Git already initialized."; fi

deps:
	mix deps.get

test:
	mix test

credo:
	mix credo

dialyzer: deps
	mix dialyzer

coverage:
	mix coveralls

check: test credo dialyzer
	@echo "All checks passed!"

format:
	mix format

clean:
	mix clean
	rm -rf _build cover

release: check
	@echo "==============================================="
	@echo "Building OTP release"
	@echo "==============================================="
	MIX_ENV=prod mix release --overwrite
	@echo ""
	@echo "✓ Release built successfully"
	@echo "Location: _build/prod/rel/rss_polling/"
	@echo ""

publish-release: release
	@echo "==============================================="
	@echo "Publishing release to GitHub"
	@echo "==============================================="
	@echo ""

	VERSION=$$(cat _build/prod/rel/rss_polling/releases/RELEASES | tail -1 | cut -d' ' -f2); \
	echo "Version: $$VERSION"; \
	\
	echo "Creating release tarball..."; \
	tar -czf rss_polling-$$VERSION.tar.gz -C _build/prod/rel rss_polling/; \
	echo "✓ Tarball created: rss_polling-$$VERSION.tar.gz"; \
	echo ""; \
	\
	echo "Creating GitHub release v$$VERSION..."; \
	gh release create v$$VERSION rss_polling-$$VERSION.tar.gz \
		--title "Release rss_polling v$$VERSION" \
		--notes "bot_army_feeds Elixir release v$$VERSION. Download and deploy with Jenkins." \
		--draft=false; \
	echo "✓ Release published to GitHub"; \
	echo ""

logs:
	@$(SCRIPTS_DIRECTORY)/tail_bot_log.sh

# Feed management targets (NATS request/reply)
# Note: These require the bot to be running with NATS available

list-feeds:
	@echo "Listing feeds..."
	nats request --server nats://localhost:4223 feeds.feed.list '{}' --timeout 3s

add-feed:
	@if [ -z "$(URL)" ]; then echo "ERROR: URL is required. Use: make add-feed URL=http://example.com/feed NAME='My Feed' CAT=tech TAGS='llm,nats'"; exit 1; fi
	@echo "Adding feed: $(URL)"
	@TAGS_JSON=$$(echo "$(TAGS)" | sed 's/,/", "/g'); \
	echo "{\"url\": \"$(URL)\", \"name\": \"$(NAME)\", \"category\": \"$(CAT)\", \"tags\": [\"$$TAGS_JSON\"]}" | \
	nats request --server nats://localhost:4223 feeds.feed.add - --timeout 3s

remove-feed:
	@if [ -z "$(URL)" ]; then echo "ERROR: URL is required. Use: make remove-feed URL=http://example.com/feed"; exit 1; fi
	@echo "Removing feed: $(URL)"
	nats request --server nats://localhost:4223 feeds.feed.remove '{"url": "$(URL)"}' --timeout 3s

poll-feeds:
	@echo "Triggering feed poll..."
	nats request --server nats://localhost:4223 feeds.poll '{}' --timeout 3s

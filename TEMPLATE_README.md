# Bot Template - Infrastructure-as-Code for Bot Repositories

This repository serves as a **template** for creating new bot repositories in the Bot Army ecosystem. It contains all the CI/CD infrastructure, documentation, and configuration files that every bot needs.

## What's Included

The template provides:

- **git-hooks/pre-push** - Pre-push hook for validation and release publishing
- **Makefile** - Development commands (setup, test, release, etc.)
- **Jenkinsfile** - CI/CD pipeline for GitHub release detection and deployment
- **mix.exs** - Elixir project configuration with OTP release setup
- **docs/SETUP.md** - Developer setup and workflow documentation

All files are parameterized with placeholders that you customize for each new bot.

## How to Use This Template

### Step 1: Copy Template to New Bot Repository

When creating a new bot (e.g., `bot_army_newbot`), copy all template files to the new repo:

```bash
cp -r bot_template/git-hooks ./
cp -r bot_template/docs ./
cp bot_template/{Makefile,Jenkinsfile,mix.exs} ./
```

### Step 2: Customize Placeholders

Replace the following placeholders throughout the copied files:

| Placeholder | Example | Description |
|-------------|---------|-------------|
| `{{BOT_APP_NAME}}` | `bot_army_newbot` | Elixir app name (snake_case) |
| `{{BOT_APP_NAME_CAMEL}}` | `BotArmyNewbot` | Elixir module name (PascalCase) |
| `{{BOT_RELEASE_NAME}}` | `newbot_bot` | OTP release name (snake_case) |
| `{{BOT_NAME_TITLE}}` | `Newbot Bot` | Display name (Title Case) |
| `{{GITHUB_REPO_SUFFIX}}` | `newbot` | GitHub repo suffix (after `ergon-`) |
| `{{DEFAULT_VERSION}}` | `0.1.0` | Version fallback in Jenkinsfile |

### Step 3: Update Infrastructure Configuration

Update `bot_army_infra/` with the new bot configuration:

1. **Add to `jenkins_bot_config.sh`:**
   ```bash
   *ergon-newbot*)
     echo "BOT_NAME=newbot_bot"
     echo "RELEASE_DIR=/opt/ergon/releases/newbot_bot"
     ;;
   ```

2. **Add to `pillar/common.sls`** (services.bots section):
   ```yaml
   newbot:
     name: newbot_bot
     release_dir: /opt/ergon/releases/newbot_bot
     github_repo: ergon-automation-labs/ergon-newbot
   ```

3. **Add schema repositories** to `pillar/common.sls` (if needed):
   ```yaml
   newbot:
     url: "git@github.com:ergon-automation-labs/ergon-schemas-newbot.git"
     dest: "/etc/bot_army/schemas/newbot"
   ```

## Parameter Mapping Example

For a new bot called `bot_army_newbot` (release name: `newbot_bot`):

| Placeholder | Value |
|-------------|-------|
| `{{BOT_APP_NAME}}` | `bot_army_newbot` |
| `{{BOT_APP_NAME_CAMEL}}` | `BotArmyNewbot` |
| `{{BOT_RELEASE_NAME}}` | `newbot_bot` |
| `{{BOT_NAME_TITLE}}` | `Newbot Bot` |
| `{{GITHUB_REPO_SUFFIX}}` | `newbot` |
| `{{DEFAULT_VERSION}}` | `0.1.0` |

## Quick Reference: Existing Bots

Use these as reference when adding new bots:

| Bot | App Name | Release Name | GitHub Repo |
|-----|----------|--------------|-------------|
| GTD | `bot_army_gtd` | `gtd_bot` | `ergon-gtd` |
| LLM | `bot_army_llm` | `llm_proxy` | `ergon-llm` |
| Fitness | `bot_army_fitness` | `fitness_bot` | `ergon-fitness` |
| Chore | `bot_army_chore` | `chore_bot` | `ergon-chore` |
| Job | `bot_army_job` | `job_bot` | `ergon-job` |

## File-by-File Placeholders

### git-hooks/pre-push
- `{{BOT_APP_NAME}}` - In comment
- `{{BOT_RELEASE_NAME}}` - Path to release directory (2 places)
- `{{BOT_NAME_TITLE}}` - In release notes

### Makefile
- `{{BOT_NAME_TITLE}}` - In help text
- `{{BOT_RELEASE_NAME}}` - In release target (2 places)

### Jenkinsfile
- `{{BOT_RELEASE_NAME}}` - Environment variable
- `{{GITHUB_REPO_SUFFIX}}` - GitHub repository URL
- `{{BOT_APP_NAME}}` - Module name in version extraction
- `{{DEFAULT_VERSION}}` - Fallback version

### mix.exs
- `{{BOT_APP_NAME_CAMEL}}` - Module name
- `{{BOT_APP_NAME}}` - App atom
- `{{BOT_RELEASE_NAME}}` - Release configuration (2 places)

### docs/SETUP.md
- All 6 placeholders used in various places for documentation accuracy

## Workflow After Setup

Once customized, each bot repo follows this workflow:

1. **Developer makes changes** and commits
2. **`git push`** triggers pre-push hook
3. **Pre-push hook:**
   - Validates compilation with `mix compile`
   - Runs linting with `mix credo`
   - Builds OTP release with `mix release`
   - Creates tarball
   - Publishes to GitHub with `gh release create`
4. **Jenkins detects new release** (polls every 5 minutes)
5. **Jenkins:**
   - Downloads tarball from GitHub
   - Extracts release
   - Deploys to `/opt/ergon/releases/{{BOT_RELEASE_NAME}}/`
   - Restarts service
   - Publishes NATS notification

## Finding and Replacing Placeholders

### Using sed (bash)
```bash
# Single bot setup
sed -i 's/{{BOT_APP_NAME}}/bot_army_newbot/g' *
sed -i 's/{{BOT_RELEASE_NAME}}/newbot_bot/g' *
```

### Using find + sed (multiple files)
```bash
find . -type f \( -name "Makefile" -o -name "Jenkinsfile" -o -name "*.exs" -o -name "*.md" \) -exec sed -i 's/{{BOT_APP_NAME}}/bot_army_newbot/g' {} \;
```

## Future Enhancements

Potential improvements to the template:

- **Automated setup script** - Single command to copy, customize, and update infrastructure config
- **CLAUDE.md template** - Bot-specific development guidelines
- **GitHub Actions workflows** - For automated testing, coverage reports
- **Contributing guidelines** - Standard contributor expectations
- **.gitignore template** - Boilerplate ignores for Elixir projects
- **Infrastructure-as-Code documentation** - How bots integrate with Salt/Jenkins

## Questions?

Refer to individual bot repositories (e.g., `bot_army_gtd`) for examples of how this template is used in practice.

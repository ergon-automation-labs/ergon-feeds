#!/bin/bash
# Setup script to create a new bot from the template
# Usage: ./setup_new_bot.sh <app_name> <release_name> <github_suffix> [title]
# Example: ./setup_new_bot.sh bot_army_newbot newbot_bot newbot "Newbot Bot"

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
error() {
  echo -e "${RED}✗ Error: $1${NC}" >&2
  exit 1
}

success() {
  echo -e "${GREEN}✓ $1${NC}"
}

info() {
  echo -e "${YELLOW}ℹ $1${NC}"
}

# Validate arguments
if [ $# -lt 3 ]; then
  echo "Usage: $0 <app_name> <release_name> <github_suffix> [title]"
  echo ""
  echo "Arguments:"
  echo "  app_name         - Elixir app name (e.g., bot_army_newbot)"
  echo "  release_name     - OTP release name (e.g., newbot_bot)"
  echo "  github_suffix    - GitHub repo suffix (e.g., newbot)"
  echo "  title (optional) - Display title (e.g., 'Newbot Bot')"
  echo ""
  echo "Example:"
  echo "  $0 bot_army_newbot newbot_bot newbot 'Newbot Bot'"
  exit 1
fi

APP_NAME="$1"
RELEASE_NAME="$2"
GITHUB_SUFFIX="$3"
TITLE="${4:-$(echo $RELEASE_NAME | sed 's/_/ /g' | sed 's/\b\(.\)/\U\1/g')}"
APP_NAME_CAMEL=$(echo "$APP_NAME" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1' | tr -d ' ')
DEFAULT_VERSION="0.1.0"

echo ""
echo "Creating new bot from template..."
echo ""
echo "Parameters:"
echo "  App Name (snake_case):    $APP_NAME"
echo "  App Name (PascalCase):    $APP_NAME_CAMEL"
echo "  Release Name:             $RELEASE_NAME"
echo "  GitHub Suffix:            $GITHUB_SUFFIX"
echo "  Display Title:            $TITLE"
echo "  Default Version:          $DEFAULT_VERSION"
echo ""

# Get the template directory
TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="../$APP_NAME"

# Check if target already exists
if [ -d "$TARGET_DIR" ]; then
  error "Target directory already exists: $TARGET_DIR"
fi

# Create target directory
mkdir -p "$TARGET_DIR"
success "Created directory: $TARGET_DIR"

# Copy template files
echo ""
info "Copying template files..."

# Copy directory structures
mkdir -p "$TARGET_DIR/git-hooks"
mkdir -p "$TARGET_DIR/docs"
mkdir -p "$TARGET_DIR/lib/$APP_NAME/skills"

# Copy and customize files
copy_and_customize() {
  local src="$1"
  local dst="$2"

  cp "$src" "$dst"

  # Replace placeholders
  sed -i '' "s|{{BOT_APP_NAME}}|$APP_NAME|g" "$dst"
  sed -i '' "s|{{BOT_APP_NAME_CAMEL}}|$APP_NAME_CAMEL|g" "$dst"
  sed -i '' "s|{{BOT_RELEASE_NAME}}|$RELEASE_NAME|g" "$dst"
  sed -i '' "s|{{BOT_NAME_TITLE}}|$TITLE|g" "$dst"
  sed -i '' "s|{{GITHUB_REPO_SUFFIX}}|$GITHUB_SUFFIX|g" "$dst"
  sed -i '' "s|{{DEFAULT_VERSION}}|$DEFAULT_VERSION|g" "$dst"

  success "Created: $dst"
}

copy_and_customize "$TEMPLATE_DIR/git-hooks/pre-push" "$TARGET_DIR/git-hooks/pre-push"
copy_and_customize "$TEMPLATE_DIR/Makefile" "$TARGET_DIR/Makefile"
copy_and_customize "$TEMPLATE_DIR/Jenkinsfile" "$TARGET_DIR/Jenkinsfile"
copy_and_customize "$TEMPLATE_DIR/mix.exs" "$TARGET_DIR/mix.exs"
copy_and_customize "$TEMPLATE_DIR/docs/SETUP.md" "$TARGET_DIR/docs/SETUP.md"
copy_and_customize "$TEMPLATE_DIR/lib/{{BOT_APP_NAME}}/skills/example.ex" "$TARGET_DIR/lib/$APP_NAME/skills/example.ex"

# Make pre-push hook executable
chmod +x "$TARGET_DIR/git-hooks/pre-push"
success "Made git-hooks/pre-push executable"

echo ""
info "Initializing git repository..."
cd "$TARGET_DIR"
git init
git config core.hooksPath git-hooks
success "Initialized git repo with core.hooksPath = git-hooks"

echo ""
info "Creating GitHub repository..."
GITHUB_REPO="ergon-$GITHUB_SUFFIX"
gh repo create "ergon-automation-labs/$GITHUB_REPO" \
  --public \
  --source=. \
  --remote=origin \
  --push \
  --description "$TITLE" 2>/dev/null || {
  error "Failed to create GitHub repository. Ensure you have 'gh' CLI installed and are authenticated."
}
success "Created GitHub repo: ergon-automation-labs/$GITHUB_REPO"

echo ""
echo "✅ Bot template setup complete!"
echo ""
echo "Next steps:"
echo "1. Update bot_army_infra/salt/common/files/jenkins_bot_config.sh"
echo "   Add:"
echo "     *ergon-$GITHUB_SUFFIX*)"
echo "       echo \"BOT_NAME=$RELEASE_NAME\""
echo "       echo \"RELEASE_DIR=/opt/ergon/releases/$RELEASE_NAME\""
echo "       ;;"
echo ""
echo "2. Update bot_army_infra/pillar/common.sls"
echo "   Add under 'services.bots':"
echo "     $GITHUB_SUFFIX:"
echo "       name: $RELEASE_NAME"
echo "       release_dir: /opt/ergon/releases/$RELEASE_NAME"
echo "       github_repo: ergon-automation-labs/ergon-$GITHUB_SUFFIX"
echo ""
echo "3. Run setup to finalize (install dependencies, etc):"
echo "   cd $TARGET_DIR && make setup"
echo ""

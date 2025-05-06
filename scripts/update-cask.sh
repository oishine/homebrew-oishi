#!/bin/bash
set -e

CASK_PATH="$1"
REPO="$2"
APP_NAME="$3"
INCLUDE_PRERELEASE="${4:-false}"
SHA_TYPE="${5:-single}"

if [ -z "$CASK_PATH" ] || [ -z "$REPO" ] || [ -z "$APP_NAME" ]; then
  echo "Usage: $0 CASK_PATH REPO APP_NAME [INCLUDE_PRERELEASE] [SHA_TYPE]"
  exit 1
fi

if [ ! -f "$CASK_PATH" ]; then
  echo "Cask file $CASK_PATH not found. Skipping."
  exit 0
fi

# Fetch releases
RELEASES_DATA=$(curl -s -H "Authorization: token $GH_PAT" "https://api.github.com/repos/$REPO/releases")

get_latest_tag() {
  local json="$1"
  local include_pre="$2"
  if command -v jq >/dev/null 2>&1; then
    if [ "$include_pre" = "true" ]; then
      echo "$json" | jq -r '.[0].tag_name'
    else
      echo "$json" | jq -r '[.[] | select(.prerelease == false)][0].tag_name'
    fi
  else
    echo "$json" | grep -m 1 '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/'
  fi
}

LATEST_TAG=$(get_latest_tag "$RELEASES_DATA" "$INCLUDE_PRERELEASE")
LATEST_VERSION=$(echo "$LATEST_TAG" | sed -E 's/^(v|release-|build-)//')

CURRENT_VERSION=$(grep -oP 'version ["'"'"']\K[^"'"'"']+' "$CASK_PATH" || echo "not-found")
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
  echo "$APP_NAME is already up to date."
  exit 0
fi

echo "Updating $APP_NAME to version $LATEST_VERSION..."

# Update version
sed -i.bak -E "s/version [\"'].*[\"']/version \"$LATEST_VERSION\"/" "$CASK_PATH"

# SHA256 Handling
TEMP_DIR=$(mktemp -d)
get_filename() { echo "$1" | sed -E 's|.*/([^/]+)$|\1|'; }

# Remove any existing sha256 (handles :no_check, single, and multi-arch)
sed -i.bak '/^\s*sha256 /d' "$CASK_PATH"

if [ "$SHA_TYPE" = "none" ]; then
  echo "Skipping sha256 update as configured."
elif [ "$SHA_TYPE" = "dual" ]; then
  ARM_URL=$(echo "$RELEASES_DATA" | jq -r --arg TAG "$LATEST_TAG" '[.[] | select(.tag_name == $TAG)][0].assets[] | select(.name | test("arm|arm64")) | .browser_download_url' | head -1)
  INTEL_URL=$(echo "$RELEASES_DATA" | jq -r --arg TAG "$LATEST_TAG" '[.[] | select(.tag_name == $TAG)][0].assets[] | select(.name | test("intel|x86_64|amd64")) | .browser_download_url' | head -1)

  if [ -z "$ARM_URL" ] || [ -z "$INTEL_URL" ]; then
    echo "❌ ARM or Intel asset not found for $APP_NAME"
    rm -rf "$TEMP_DIR"
    exit 1
  fi

  ARM_FILE="$TEMP_DIR/$(get_filename "$ARM_URL")"
  INTEL_FILE="$TEMP_DIR/$(get_filename "$INTEL_URL")"

  curl -L "$ARM_URL" -o "$ARM_FILE"
  curl -L "$INTEL_URL" -o "$INTEL_FILE"

  ARM_SHA256=$(shasum -a 256 "$ARM_FILE" | awk '{ print $1 }')
  INTEL_SHA256=$(shasum -a 256 "$INTEL_FILE" | awk '{ print $1 }')

  sed -i.bak -E "/^  version/ a\\
  sha256 arm:   \"$ARM_SHA256\",\\
         intel: \"$INTEL_SHA256\"
" "$CASK_PATH"

elif [ "$SHA_TYPE" = "single" ]; then
  UNIVERSAL_URL=$(echo "$RELEASES_DATA" | jq -r --arg TAG "$LATEST_TAG" '[.[] | select(.tag_name == $TAG)][0].assets[0].browser_download_url')
  UNIVERSAL_FILE="$TEMP_DIR/$(get_filename "$UNIVERSAL_URL")"
  curl -L "$UNIVERSAL_URL" -o "$UNIVERSAL_FILE"
  UNIVERSAL_SHA256=$(shasum -a 256 "$UNIVERSAL_FILE" | awk '{ print $1 }')

  sed -i.bak -E "/^  version/ a\\
  sha256 \"$UNIVERSAL_SHA256\"
" "$CASK_PATH"
fi

rm -rf "$TEMP_DIR"
rm -f "$CASK_PATH.bak"


# Git operations
BRANCH_NAME="update-${APP_NAME,,}-$LATEST_VERSION"
BRANCH_NAME=${BRANCH_NAME// /-}

git checkout -b "$BRANCH_NAME"
git add "$CASK_PATH"
git commit -S -m "$APP_NAME: v$LATEST_VERSION"
git push origin "$BRANCH_NAME" -f

# Detect repo from actual git remote
GIT_REMOTE_URL=$(git config --get remote.origin.url)
if [[ "$GIT_REMOTE_URL" =~ github\.com[:/](.*)/(.*)(\.git)?$ ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO_NAME_ONLY="${BASH_REMATCH[2]}"
else
  echo "❌ Could not determine GitHub repo from git remote URL."
  exit 1
fi

# Confirm branch exists on remote
if ! git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
  echo "❌ Branch $BRANCH_NAME not found on remote. Did push fail?"
  exit 1
fi

PR_RESPONSE=$(curl -s -X POST \
  -H "Authorization: token $GH_PAT" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$OWNER/$REPO_NAME_ONLY/pulls" \
  -d @- <<EOF
{
  "title": "$APP_NAME: v$LATEST_VERSION",
  "body": "Update $APP_NAME to v$LATEST_VERSION",
  "head": "$BRANCH_NAME",
  "base": "main"
}
EOF
)

PR_URL=$(echo "$PR_RESPONSE" | grep -o '"html_url": "[^"]*"' | cut -d'"' -f4)

if [ -n "$PR_URL" ]; then
  echo "Pull request created: $PR_URL"
else
  echo "Failed to create PR. Response: $PR_RESPONSE"
fi

echo "Done with $APP_NAME"

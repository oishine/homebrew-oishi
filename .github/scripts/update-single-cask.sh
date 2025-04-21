#!/bin/bash

# Exit on error
set -e

CASK_PATH="$1"
REPO="$2"
APP_NAME="$3"
INCLUDE_PRERELEASE="${4:-false}"

# Check if parameters are provided
if [ -z "$CASK_PATH" ] || [ -z "$REPO" ] || [ -z "$APP_NAME" ]; then
  echo "Error: Missing parameters. Usage: $0 CASK_PATH REPO APP_NAME [INCLUDE_PRERELEASE]"
  exit 1
fi

# Check if cask file exists
if [ ! -f "$CASK_PATH" ]; then
  echo "Warning: Cask file $CASK_PATH does not exist. Skipping."
  exit 0
fi

echo "Fetching latest release for $APP_NAME from $REPO (Include pre-releases: $INCLUDE_PRERELEASE)..."

# Fetch release data
RELEASES_DATA=$(curl -s -H "Authorization: token $GH_PAT" "https://api.github.com/repos/$REPO/releases")

# Function to get latest tag
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
    if [ "$include_pre" = "true" ]; then
      echo "$json" | grep -m 1 '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/'
    else
      echo "$json" | grep -B 5 '"prerelease": false' | grep '"tag_name":' | head -1 | sed -E 's/.*"tag_name": "([^"]+)".*/\1/'
    fi
  fi
}

# Extract tag
LATEST_TAG=$(get_latest_tag "$RELEASES_DATA" "$INCLUDE_PRERELEASE")

if [ -z "$LATEST_TAG" ]; then
  echo "Warning: Could not determine the latest tag. Skipping."
  exit 0
fi

# Clean version string (e.g. remove v, release-, build- prefixes)
LATEST_VERSION=$(echo "$LATEST_TAG" | sed -E 's/^(v|release-|build-)//')

echo "$APP_NAME latest version: $LATEST_VERSION (from tag: $LATEST_TAG)"

# Extract current version from cask
CURRENT_VERSION=$(grep -oP 'version ["'"'"']\K[^"'"'"']+' "$CASK_PATH" || echo "not-found")
echo "$APP_NAME current version in cask: $CURRENT_VERSION"

# Skip if already up to date
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
  echo "$APP_NAME is already up to date. Skipping."
  exit 0
fi

if [ "$CURRENT_VERSION" = "not-found" ]; then
  echo "Warning: Could not find version in $CASK_PATH. Skipping."
  exit 0
fi

echo "Updating $APP_NAME from version $CURRENT_VERSION to $LATEST_VERSION..."

# Update cask version
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' -E "s/version [\"']$CURRENT_VERSION[\"']/version \"$LATEST_VERSION\"/" "$CASK_PATH"
else
  sed -i -E "s/version [\"']$CURRENT_VERSION[\"']/version \"$LATEST_VERSION\"/" "$CASK_PATH"
fi

# Create Git branch
BRANCH_NAME="update-${APP_NAME,,}-$LATEST_VERSION"
BRANCH_NAME=${BRANCH_NAME// /-}

echo "Creating branch: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME"

git add "$CASK_PATH"
git commit -m "$APP_NAME: v$LATEST_VERSION"
git push origin "$BRANCH_NAME" -f

# Create pull request
echo "Creating pull request..."

# Extract repo owner and name from GITHUB_REPOSITORY env var
REPO_PARTS=(${REPO_NAME//\// })
if [ ${#REPO_PARTS[@]} -ge 2 ]; then
  OWNER=${REPO_PARTS[0]}
  REPO_NAME_ONLY=${REPO_PARTS[1]}
else
  OWNER=$REPO_OWNER
  REPO_NAME_ONLY=$REPO_NAME
fi

PR_RESPONSE=$(curl -s -X POST \
  -H "Authorization: token $GH_PAT" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$OWNER/$REPO_NAME_ONLY/pulls" \
  -d @- <<EOF
{
  "title": "$APP_NAME: v$LATEST_VERSION",
  "body": "Update $APP_NAME to $LATEST_VERSION",
  "head": "$BRANCH_NAME",
  "base": "main"
}
EOF
)

PR_URL=$(echo "$PR_RESPONSE" | grep -o '"html_url": "[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$PR_URL" ]; then
  echo "PR created for $APP_NAME: $PR_URL"
else
  echo "Warning: Failed to create PR. Response: $PR_RESPONSE"
fi

echo "Done processing $APP_NAME."

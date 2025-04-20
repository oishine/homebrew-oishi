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

if [ "$INCLUDE_PRERELEASE" = "true" ]; then
  # If pre-releases are included, fetch all releases and pick the first one
  RELEASES_URL="https://api.github.com/repos/$REPO/releases"
  echo "Checking all releases (including pre-releases)"
else
  # If only stable releases, use the latest release endpoint (excludes pre-releases)
  RELEASES_URL="https://api.github.com/repos/$REPO/releases/latest"
  echo "Checking only stable releases"
fi

# Fetch release information
if [ "$INCLUDE_PRERELEASE" = "true" ]; then
  # For pre-releases, get all releases and pick the first (which could be a pre-release)
  RELEASE_DATA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "$RELEASES_URL")
  LATEST_TAG=$(echo "$RELEASE_DATA" | grep -m 1 '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
else
  # For stable only, use the latest release endpoint
  RELEASE_DATA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "$RELEASES_URL")
  LATEST_TAG=$(echo "$RELEASE_DATA" | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
fi

# Handle case when no releases are found
if [ -z "$LATEST_TAG" ]; then
  echo "Warning: No releases found for $REPO. Trying alternative approach..."

  # Try listing all releases and filter based on pre-release preference
  RELEASES_DATA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$REPO/releases")

  if [ "$INCLUDE_PRERELEASE" = "true" ]; then
    # Get the first release regardless of pre-release status
    LATEST_TAG=$(echo "$RELEASES_DATA" | grep -m 1 '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
  else
    # Filter to exclude pre-releases
    LATEST_TAG=$(echo "$RELEASES_DATA" | grep -B 5 '"prerelease": false' | grep '"tag_name":' | head -1 | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')
  fi

  if [ -z "$LATEST_TAG" ]; then
    echo "Warning: Could not find any suitable releases for $REPO. Skipping."
    exit 0
  fi
fi

# Clean version string (remove common prefixes like 'v', 'release-')
LATEST_VERSION=$(echo $LATEST_TAG | sed -E 's/^[vr]|-release//g')
echo "$APP_NAME latest version: $LATEST_VERSION (from tag: $LATEST_TAG)"

# Extract current version from cask file
CURRENT_VERSION=$(grep -oP 'version ["'"'"']\K[^"'"'"']+' $CASK_PATH || echo "not-found")
echo "$APP_NAME current version in cask: $CURRENT_VERSION"

# Skip if versions are the same
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
  echo "$APP_NAME is already up to date. Skipping."
  exit 0
fi

# Handle case when version wasn't found
if [ "$CURRENT_VERSION" = "not-found" ]; then
  echo "Warning: Could not find version in $CASK_PATH. Skipping."
  exit 0
fi

echo "Updating $APP_NAME from version $CURRENT_VERSION to $LATEST_VERSION..."

# Update the version in the cask file
sed -i "s/version [\"']$CURRENT_VERSION[\"']/version \"$LATEST_VERSION\"/" $CASK_PATH

# Create branch, commit, and push changes
BRANCH_NAME="update-${APP_NAME,,}-$LATEST_VERSION"
BRANCH_NAME=${BRANCH_NAME// /-}

echo "Creating branch: $BRANCH_NAME"
git checkout -b $BRANCH_NAME

git add $CASK_PATH
git commit -m "$APP_NAME: v$LATEST_VERSION"
git push origin $BRANCH_NAME -f

# Create PR using GitHub API with curl - to YOUR repository
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

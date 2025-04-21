#!/bin/bash

set -e

source .github/scripts/casks-config.sh

# Process each cask defined in the configuration
for CASK_INFO in "${CASKS[@]}"; do
  # Parse cask info
  CASK_PATH=$(echo $CASK_INFO | cut -d'|' -f1)
  REPO=$(echo $CASK_INFO | cut -d'|' -f2)
  APP_NAME=$(echo $CASK_INFO | cut -d'|' -f3)
  INCLUDE_PRERELEASE=$(echo $CASK_INFO | cut -d'|' -f4)

  echo "============================================="
  echo "Processing $APP_NAME ($CASK_PATH) from $REPO"
  echo "Pre-release inclusion: $INCLUDE_PRERELEASE"
  echo "============================================="

  ./scripts/update-single-cask.sh "$CASK_PATH" "$REPO" "$APP_NAME" "$INCLUDE_PRERELEASE"

  # Return to main branch for the next cask
  git checkout main
done

echo "All casks processed successfully!"

#!/bin/bash

# Define the list of casks to check and their respective GitHub repositories
# Format: "CaskPath|RepoOwner/RepoName|AppName|PreRelease"
# PreRelease: Set to "true" to include pre-release versions, "false" for stable releases only
CASKS=(
  "Casks/pcsx2.rb|PCSX2/pcsx2|pcsx2|true"
  "Casks/vencordinstaller.rb|Vencord/Installer|vencordinstaller|false"
)

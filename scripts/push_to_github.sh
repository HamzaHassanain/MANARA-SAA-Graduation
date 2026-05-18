#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI not found. Install it or run the manual `gh repo create` command shown in README.md."
  exit 1
fi

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <repo-name> [--private]"
  echo "Example: $0 MANARA-SAA-Graduation"
  exit 1
fi

REPO="$1"

echo "Creating private repo: $REPO and pushing current code..."
gh repo create "$REPO" --private --source=. --remote=origin --push

echo "Repository created and initial push completed."
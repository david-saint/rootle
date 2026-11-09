#!/bin/zsh
# Writes Config/Secrets.xcconfig from ANTHROPIC_API_KEY (taken from the environment, or from ~/.zsh_secrets).
# The key is never printed. Rebuild the app afterwards.
set -e
cd "$(dirname "$0")/.."
if [[ -z "$ANTHROPIC_API_KEY" && -f ~/.zsh_secrets ]]; then
  source ~/.zsh_secrets >/dev/null 2>&1
fi
if [[ -z "$ANTHROPIC_API_KEY" ]]; then
  echo "ANTHROPIC_API_KEY is not set; word generation will be off." >&2
  exit 1
fi
umask 077
printf 'ROOTLE_ANTHROPIC_KEY = %s\n' "$ANTHROPIC_API_KEY" > Config/Secrets.xcconfig
echo "Wrote Config/Secrets.xcconfig"

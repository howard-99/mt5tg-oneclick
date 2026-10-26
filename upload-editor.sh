#!/usr/bin/env bash
# Upload only to the existing PRIVATE MT5-to-Telegram release.
set -Eeuo pipefail
umask 077
readonly REPO='howard-99/MT5-to-Telegram'
readonly TAG='v21.26.0'
readonly PIN='66fef88fe6a5d6071163a31ea46b3382ab482e19239b048f5fd578e8a13bd03a'
path=${1:-/root/MetaEditor64.exe}
[[ -f $path && -s $path ]] || { echo "Missing $path" >&2; exit 1; }
command -v gh >/dev/null || { echo 'Install gh: apt-get update && apt-get install -y gh' >&2; exit 1; }
gh auth status --hostname github.com >/dev/null 2>&1 || { echo 'Run gh auth login --hostname github.com --web' >&2; exit 1; }
actual=$(sha256sum "$path" | awk '{print $1}')
[[ $actual == "$PIN" ]] || { echo "SHA mismatch $actual (expected $PIN)" >&2; exit 1; }
[[ $(basename "$path") == MetaEditor64.exe ]] || {
  echo 'The private GitHub release asset must be named MetaEditor64.exe.' >&2; exit 1;
}
visibility=$(gh api repos/$REPO --jq .private)
[[ $visibility == true ]] || { echo 'Refusing upload because platform repository is not PRIVATE.' >&2; exit 1; }
echo 'Verified trusted MetaEditor64.exe. Uploading to PRIVATE release only.' >&2
gh release upload "$TAG" "$path" --repo "$REPO"
echo 'Private release asset published. Public helper repo must never include this EXE.' >&2

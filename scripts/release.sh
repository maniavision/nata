#!/usr/bin/env bash
# Starts a store release: raises the version name in pubspec.yaml, commits it
# on main and tags it v<version>. Pushing the tag makes Codemagic build for the
# App Store and Google Play production (see docs/RELEASING.md).
#
#   bash scripts/release.sh patch        1.2.3 -> 1.2.4  (fixes)
#   bash scripts/release.sh minor        1.2.3 -> 1.3.0  (new features)
#   bash scripts/release.sh major        1.2.3 -> 2.0.0  (big changes)
#   bash scripts/release.sh 1.4.0        an exact version
#   add --push to push the commit and the tag straight away
#
# The build number (after the +) isn't yours to manage: Codemagic sets it to
# one more than the highest already in each store.
set -euo pipefail

cd "$(dirname "$0")/.."

BUMP="${1:-}"
PUSH=false
[ "${2:-}" = "--push" ] && PUSH=true
if [ -z "$BUMP" ]; then
  sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "Commit or set aside your changes first."; exit 1
fi
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" != "main" ]; then
  echo "Releases are made from main (you're on $BRANCH)."; exit 1
fi
git fetch -q origin main
# Ahead of GitHub is fine (unpushed commits); behind or diverged is not.
if ! git merge-base --is-ancestor origin/main HEAD; then
  echo "main is behind origin/main. Run: git pull"; exit 1
fi

LINE=$(grep -E '^version:' pubspec.yaml)
CURRENT=$(echo "$LINE" | sed -E 's/version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
BUILD=$(echo "$LINE" | sed -nE 's/.*\+([0-9]+).*/\1/p')
IFS=. read -r MAJOR MINOR PATCH <<< "$CURRENT"

case "$BUMP" in
  major) NEXT="$((MAJOR + 1)).0.0" ;;
  minor) NEXT="$MAJOR.$((MINOR + 1)).0" ;;
  patch) NEXT="$MAJOR.$MINOR.$((PATCH + 1))" ;;
  *)
    if [[ "$BUMP" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then NEXT="$BUMP"
    else echo "Use patch, minor, major or a version like 1.4.0."; exit 1; fi ;;
esac

# The new version must be higher than the current one.
if [ "$(printf '%s\n%s\n' "$CURRENT" "$NEXT" | sort -V | tail -1)" != "$NEXT" ] \
   || [ "$CURRENT" = "$NEXT" ]; then
  echo "$NEXT isn't higher than the current $CURRENT."; exit 1
fi
if git rev-parse -q --verify "refs/tags/v$NEXT" >/dev/null; then
  echo "Tag v$NEXT already exists."; exit 1
fi

# Keep the local build number (Codemagic replaces it for store builds).
sed -i.bak -E "s/^version:.*/version: $NEXT+${BUILD:-1}/" pubspec.yaml
rm -f pubspec.yaml.bak

git add pubspec.yaml
git commit -q -m "Release $NEXT"
git tag -a "v$NEXT" -m "Nata $NEXT"
echo "Version $CURRENT -> $NEXT: committed and tagged v$NEXT."

if $PUSH; then
  git push -q origin main "v$NEXT"
  echo "Pushed. Codemagic is building v$NEXT for the App Store and Google Play."
else
  echo "To release it, push the commit and the tag:"
  echo "  git push origin main v$NEXT"
fi

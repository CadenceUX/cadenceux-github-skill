#!/usr/bin/env bash
# Builds a skill's release archives from its Git tag.
#
#   bash scripts/build_release.sh <version> [repo-path]
#
# Run from anywhere; repo-path defaults to the current folder. Needs git and tar, which macOS,
# Linux and Git Bash on Windows all have. Writes to <repo>/dist/:
#   <name>-v<version>.zip  <name>-v<version>.skill  <name>.zip  <name>.skill
# The .skill file is the same zip renamed (the Claude app on macOS opens it on double-click).
# Unversioned copies let README links to releases/latest/download/<name>.zip always resolve.

set -euo pipefail

fail() { echo "build_release: $*" >&2; exit 1; }

version="${1:-}"
repo="${2:-.}"
[ -n "$version" ] || fail "usage: bash scripts/build_release.sh <version> [repo-path]  (e.g. 1.0.0)"
version="${version#v}"
tag="v$version"

cd "$repo" || fail "can't open $repo"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "$repo is not a Git repository"
git rev-parse -q --verify "refs/tags/$tag" >/dev/null \
  || fail "tag $tag doesn't exist. Commit, then: git tag $tag && git push origin $tag"

# Read files as committed at the tag, not as they sit in the working folder.
at_tag() { git show "$tag:$1" 2>/dev/null; }

skill_md="$(at_tag SKILL.md)" || fail "no SKILL.md at the repo root in $tag"

# Frontmatter is the block between the first two '---' lines.
frontmatter="$(printf '%s\n' "$skill_md" | awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f')"
[ -n "$frontmatter" ] || fail "SKILL.md in $tag has no frontmatter"

name="$(printf '%s\n' "$frontmatter" | sed -n 's/^name:[[:space:]]*//p' | head -1 | tr -d '"'"'"' \r')"
[ -n "$name" ] || fail "SKILL.md frontmatter has no name"
printf '%s' "$name" | grep -Eq '^[a-z0-9-]{1,64}$' \
  || fail "name '$name' must be lowercase letters, digits and hyphens, at most 64 characters"

# Every version the repo carries must equal the one being released.
problems=""
meta_version="$(printf '%s\n' "$frontmatter" | sed -n 's/^[[:space:]]*version:[[:space:]]*//p' | head -1 | tr -d '"'"'"' \r')"
[ -z "$meta_version" ] || [ "$meta_version" = "$version" ] \
  || problems="$problems\n  SKILL.md metadata.version is $meta_version"

if file_version="$(at_tag VERSION)"; then
  file_version="$(printf '%s' "$file_version" | tr -d ' \r\n')"
  [ "$file_version" = "$version" ] || problems="$problems\n  VERSION is $file_version"
fi

if plugin_json="$(at_tag .claude-plugin/plugin.json)"; then
  plugin_version="$(printf '%s\n' "$plugin_json" | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  [ "$plugin_version" = "$version" ] || problems="$problems\n  .claude-plugin/plugin.json version is ${plugin_version:-missing}"
fi

if changelog="$(at_tag CHANGELOG.md)"; then
  top_heading="$(printf '%s\n' "$changelog" | grep -m1 '^## ' || true)"
  printf '%s' "$top_heading" | grep -q "$version" \
    || problems="$problems\n  newest CHANGELOG.md heading is '${top_heading:-none}'"
fi

[ -z "$problems" ] || fail "version mismatch with $version in $tag:$(printf "$problems")
Fix them, commit, and tag the next version (never move a pushed tag)."

# Check the contents first, through a tar listing of the same tree (tar is everywhere; unzip
# isn't), so a failed check leaves any earlier archives in dist/ untouched. --prefix gives the
# archive one top-level folder named after the skill, which is what Claude's skill upload
# expects; git archive honours .gitattributes export-ignore as committed at the tag.
listing="$(git archive --format=tar --prefix="$name/" "$tag" | tar -t)"
printf '%s\n' "$listing" | grep -qx "$name/SKILL.md" || fail "archive has no $name/SKILL.md"
if printf '%s\n' "$listing" | grep -q "^$name/\.claude-plugin/"; then
  fail "archive contains .claude-plugin/, which the Claude app's skill upload rejects.
Add '.claude-plugin/ export-ignore' to .gitattributes, commit, and tag the next version."
fi
for f in README.md; do
  printf '%s\n' "$listing" | grep -qx "$name/$f" || echo "build_release: warning: no $f in the archive" >&2
done
count="$(printf '%s\n' "$listing" | grep -vc '/$' || true)"
[ "$count" -le 200 ] || echo "build_release: warning: $count files; Claude uploads fail above roughly 200" >&2

mkdir -p dist
base="dist/$name-v$version"
rm -f "$base.zip" "$base.skill" "dist/$name.zip" "dist/$name.skill"   # zip would append, not replace
git archive --format=zip --prefix="$name/" -o "$base.zip" "$tag"
cp "$base.zip" "$base.skill"
cp "$base.zip" "dist/$name.zip"
cp "$base.zip" "dist/$name.skill"

echo "Built $name $tag from the tag ($count files):"
printf '%s\n' "$listing" | sed 's/^/  /'
echo "Archives:"
ls -1 "$base.zip" "$base.skill" "dist/$name.zip" "dist/$name.skill" | sed 's/^/  /'
echo "Attach all four: gh release create $tag --verify-tag --title \"$tag\" --notes-file release-notes.md $base.zip $base.skill dist/$name.zip dist/$name.skill"

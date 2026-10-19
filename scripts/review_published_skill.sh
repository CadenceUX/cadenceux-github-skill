#!/usr/bin/env bash
# Reports whether published skills need attention: unreleased changes, versions that disagree,
# a release missing its archives, open issues, or an installed copy behind the release.
#
#   bash scripts/review_published_skill.sh <skill-repo> [<skill-repo> ...]
#
# Each argument is a local clone of a skill repo (SKILL.md at its root). Read-only: it fetches
# tags but changes nothing. Needs git; uses gh (GitHub CLI) for releases and issues and the
# claude CLI for the installed plugin version, and says so when either is missing.
#
# Exit 0: nothing needs doing. Exit 1: at least one repo has an action. Exit 2: usage error.

set -uo pipefail

[ $# -ge 1 ] || { echo "usage: bash scripts/review_published_skill.sh <skill-repo> [<skill-repo> ...]" >&2; exit 2; }

have() { command -v "$1" >/dev/null 2>&1; }

# The installed Claude Code plugins, read once: "name version" per line.
installed=""
if have claude; then
  installed="$(claude plugin list 2>/dev/null | awk '
    /❯ / { split($2, a, "@"); name = a[1]; next }
    /Version:/ && name != "" { print name, $2; name = "" }')"
fi

any_action=0
for repo in "$@"; do
  echo "== $repo"
  if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "  not a Git repository; skipped"; any_action=1; continue
  fi
  actions=()

  # Versions at HEAD, in the four places they live.
  fm="$(awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f' "$repo/SKILL.md" 2>/dev/null)"
  name="$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1 | tr -d '"'"'"' \r')"
  name="${name:-$(basename "$repo")}"
  v_skill="$(printf '%s\n' "$fm" | sed -n 's/^[[:space:]]*version:[[:space:]]*//p' | head -1 | tr -d '"'"'"' \r')"
  v_file="$(tr -d ' \r\n' < "$repo/VERSION" 2>/dev/null)"
  v_plugin="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$repo/.claude-plugin/plugin.json" 2>/dev/null | head -1)"
  v_log="$(grep -m1 '^## ' "$repo/CHANGELOG.md" 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
  echo "  skill: $name"
  echo "  versions: SKILL.md ${v_skill:--}, VERSION ${v_file:--}, plugin.json ${v_plugin:--}, CHANGELOG ${v_log:--}"
  distinct="$(printf '%s\n' "$v_skill" "$v_file" "$v_plugin" "$v_log" | grep -v '^$' | sort -u | wc -l | tr -d ' ')"
  [ "$distinct" -le 1 ] || actions+=("versions disagree: make all four match before the next release")
  current="${v_file:-$v_skill}"

  # Tags, unreleased commits and uncommitted work.
  remote="$(git -C "$repo" remote get-url origin 2>/dev/null || true)"
  if [ -n "$remote" ]; then
    git -C "$repo" fetch --quiet --tags origin 2>/dev/null || echo "  (couldn't reach origin; using local tags)"
  else
    actions+=("no remote: not on GitHub yet (first publish, step 5)")
  fi
  last_tag="$(git -C "$repo" describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)"
  if [ -z "$last_tag" ]; then
    echo "  last tag: none"
    actions+=("never released: first publish, step 7")
  else
    since="$(git -C "$repo" rev-list --count "$last_tag"..HEAD)"
    echo "  last tag: $last_tag, $since commit(s) since"
    if [ "$since" -gt 0 ]; then
      git -C "$repo" log --oneline -10 "$last_tag"..HEAD | sed 's/^/    /'
      actions+=("$since commit(s) since $last_tag not released: ship an update")
    fi
    [ "${last_tag#v}" = "$current" ] || [ "$since" -gt 0 ] || actions+=("tag $last_tag doesn't match VERSION $current")
  fi
  dirty="$(git -C "$repo" status --porcelain | wc -l | tr -d ' ')"
  [ "$dirty" -eq 0 ] || actions+=("$dirty uncommitted change(s): commit or discard before releasing")
  if git -C "$repo" rev-parse -q --verify '@{u}' >/dev/null 2>&1; then
    ahead="$(git -C "$repo" rev-list --count '@{u}..HEAD')"
    [ "$ahead" -eq 0 ] || actions+=("$ahead local commit(s) not pushed")
  fi

  # GitHub: latest release, its archives, open issues and pull requests.
  slug="$(printf '%s' "$remote" | sed -En 's#^(https://github\.com/|git@github\.com:)([^/]+/[^/.]+)(\.git)?/?$#\2#p')"
  release=""
  if [ -n "$slug" ] && have gh; then
    rel="$(gh release view --repo "$slug" --json tagName,assets --jq '.tagName + " " + ([.assets[].name] | join(","))' 2>/dev/null || true)"
    if [ -z "$rel" ]; then
      echo "  GitHub release: none"
      [ -z "$last_tag" ] || actions+=("tag $last_tag has no GitHub release: gh release create")
    else
      release="${rel%% *}"; assets="${rel#* }"
      echo "  GitHub release: $release"
      [ -z "$last_tag" ] || [ "$release" = "$last_tag" ] || actions+=("latest release is $release but newest tag is $last_tag")
      for a in "$name.zip" "$name.skill"; do
        printf '%s' ",$assets," | grep -q ",$a," || actions+=("release $release has no $a: README's latest/download link breaks")
      done
    fi
    issues="$(gh issue list --repo "$slug" --state open --json number --jq length 2>/dev/null || echo "?")"
    prs="$(gh pr list --repo "$slug" --state open --json number --jq length 2>/dev/null || echo "?")"
    echo "  open issues: $issues, open pull requests: $prs"
    [ "$issues" = "0" ] || [ "$issues" = "?" ] || actions+=("$issues open issue(s) to read")
    [ "$prs" = "0" ] || [ "$prs" = "?" ] || actions+=("$prs open pull request(s) to review")
  elif [ -n "$slug" ]; then
    echo "  GitHub: gh not installed; releases and issues not checked"
  fi

  # The copy installed in Claude Code, if any.
  if have claude; then
    inst="$(printf '%s\n' "$installed" | awk -v n="$name" '$1==n {print $2; exit}')"
    if [ -n "$inst" ]; then
      echo "  installed in Claude Code: $inst"
      want="${release#v}"; want="${want:-$current}"
      [ "$inst" = "$want" ] || actions+=("installed copy is $inst, release is $want: claude plugin marketplace update, then claude plugin update")
    else
      echo "  installed in Claude Code: no"
    fi
  else
    echo "  installed in Claude Code: not checked (claude CLI not found)"
  fi

  if [ ${#actions[@]} -eq 0 ]; then
    echo "  nothing to do"
  else
    any_action=1
    printf '  ACTION: %s\n' "${actions[@]}"
  fi
done

echo
echo "Content freshness (vendor changes, Claude app rules, eval results) isn't checked here."
exit $any_action

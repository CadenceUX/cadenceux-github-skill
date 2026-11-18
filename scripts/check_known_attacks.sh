#!/usr/bin/env bash
# Checks for known attacks on GitHub: your Git tools, local repo clones and, optionally, every
# repo an account owns. Indicators come from references/known-attacks.tsv (wfx, Gheist,
# GhostAction, compromised Actions, unpatched Git), so new campaigns are a data change.
#
#   bash scripts/check_known_attacks.sh [--account <owner>] [<repo-clone> ...]
#
# With no arguments it checks the tools only. Read-only: it changes no file, ref or setting.
# git log --all is used throughout, because these attacks revert their own commits within
# seconds and the revert leaves both commits in history. Needs git, grep and awk; uses gh
# (signed in) for --account and says so when it's missing. macOS, Linux, Git Bash on Windows.
#
# Exit 0: no high or medium findings. Exit 1: findings to read. Exit 2: usage error.
# A clean result is not a guarantee: it only knows the indicators in the data file.

set -uo pipefail

usage() { echo "usage: bash scripts/check_known_attacks.sh [--account <owner>] [<repo-clone> ...]" >&2; exit 2; }

here="$(cd "$(dirname "$0")" && pwd)"
data="$here/../references/known-attacks.tsv"
[ -f "$data" ] || data="$here/known-attacks.tsv"   # downloaded beside the script
[ -f "$data" ] || { echo "check: can't find $data" >&2; exit 2; }

account=""; repos=()
while [ $# -gt 0 ]; do
  case "$1" in
    --account) [ -n "${2:-}" ] || usage; account="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) repos+=("$1"); shift ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }
TAB="$(printf '\t')"
n_high=0; n_medium=0; n_low=0

# Rows of one kind: pattern<TAB>confidence<TAB>campaign<TAB>note
rows() { grep -v '^#' "$data" | grep -v '^[[:space:]]*$' | awk -F'\t' -v k="$1" '$1==k { print $2 "\t" $3 "\t" $4 "\t" $5 }'; }

finding() {   # level campaign message [note]
  local level="$1"; shift
  case "$level" in high) n_high=$((n_high+1));; medium) n_medium=$((n_medium+1));; *) n_low=$((n_low+1));; esac
  printf '  [%s] %s: %s\n' "$(printf '%s' "$level" | tr '[:lower:]' '[:upper:]')" "$1" "$2"
  [ -n "${3:-}" ] && printf '         %s\n' "$3"
  return 0
}

# Numeric version compare on dot-separated parts: ver_lt 2.56.0 2.56.1 is true.
ver_lt() { awk -v a="$1" -v b="$2" 'BEGIN { n=split(a,x,"."); m=split(b,y,"."); k=(n>m?n:m)
  for (i=1;i<=k;i++) { p=x[i]+0; q=y[i]+0; if (p<q) exit 0; if (p>q) exit 1 } exit 1 }'; }

# ---------------------------------------------------------------------------------------------
echo "== Tools"
oldest_line=""; newest_line=""
fixed_rows="$(rows git_fixed)"
oldest_line="$(printf '%s\n' "$fixed_rows" | head -1 | cut -f1 | cut -d. -f1,2)"
newest_fixed="$(printf '%s\n' "$fixed_rows" | tail -1 | cut -f1)"
gits="$( (which -a git 2>/dev/null || command -v git) | awk '!seen[$0]++')"
if [ -z "$gits" ]; then
  echo "  git not found"
else
  while IFS= read -r g; do
    [ -x "$g" ] || continue
    raw="$("$g" --version 2>/dev/null)"
    v="$(printf '%s' "$raw" | awk '{print $3}' | sed 's/\.windows\..*//')"
    line="$(printf '%s' "$v" | cut -d. -f1,2)"
    fixed="$(printf '%s\n' "$fixed_rows" | awk -F'\t' -v l="$line" 'index($1, l".")==1 {print $1}' | head -1)"
    vendor=""
    case "$raw" in *Apple*) vendor=" Apple ships its own builds with the Xcode Command Line Tools: run Software Update.";; esac
    case "$raw" in *windows*) vendor=" Git for Windows numbers its fixes .windows.N: check git-scm.com for the current build.";; esac
    if [ -n "$fixed" ]; then
      if ver_lt "$v" "$fixed"; then
        finding high "Git" "$g is $raw, missing the November 2026 security fixes" "Update to $fixed or later (latest $newest_fixed).$vendor"
      else
        echo "  ok: $g ($raw)"
      fi
    elif ver_lt "$line.0" "$oldest_line.0"; then
      finding high "Git" "$g is $raw, a release line that no longer gets security fixes" "Update to $newest_fixed or later, or remove this copy if nothing uses it.$vendor"
    else
      echo "  ok: $g ($raw) is newer than every release line in the data file"
    fi
  done <<< "$gits"
fi
if have gh; then
  echo "  gh: $(gh --version 2>/dev/null | head -1)"
else
  echo "  gh: not installed (needed for --account)"
fi
# A credential helper that points at a program that no longer exists makes every push fail.
helpers="$(git config --get-regexp '^credential\..*helper$' 2>/dev/null | cut -d' ' -f2- | sed 's/^!//' | awk '{print $1}' | sort -u || true)"
if [ -n "$helpers" ]; then
  while IFS= read -r h; do
    cmd="$h"
    case "$cmd" in /*) [ -x "$cmd" ] || finding medium "Git sign-in" "credential helper points at $cmd, which doesn't exist" "Pushes will fail. If it's gh, run: gh auth setup-git" ;; esac
  done <<< "$helpers"
fi

# ---------------------------------------------------------------------------------------------
check_repo() {
  local repo="$1"
  echo "== $repo"
  if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "  not a Git repository; skipped"; return
  fi
  local log; log="$(git -C "$repo" log --all --format="%h${TAB}%aI${TAB}%an${TAB}%G?${TAB}%s" 2>/dev/null)"
  local before=$((n_high+n_medium+n_low))

  # Commit subjects, across every ref (the payload commit survives its revert).
  while IFS="$TAB" read -r pat conf camp note; do
    [ -n "$pat" ] || continue
    local m; m="$(printf '%s\n' "$log" | grep -E "${TAB}${pat#^}")"
    [ -n "$m" ] && while IFS="$TAB" read -r h d a sig s; do
      local signed="unsigned"; [ "$sig" = "N" ] || signed="signature $sig"
      finding "$conf" "$camp" "commit $h \"$s\" by $a, $d ($signed)" "$note"
    done <<< "$m"
  done < <(rows commit)

  # File paths ever added, in any commit.
  local paths; paths="$(git -C "$repo" log --all --format= --name-only 2>/dev/null | sort -u)"
  while IFS="$TAB" read -r pat conf camp note; do
    [ -n "$pat" ] || continue
    local m; m="$(printf '%s\n' "$paths" | grep -E "$pat")"
    [ -n "$m" ] && while IFS= read -r p; do
      local first; first="$(git -C "$repo" log --all --diff-filter=A --format='%h %aI' -- "$p" </dev/null | tail -1)"
      finding "$conf" "$camp" "file $p (added in $first)" "$note"
    done <<< "$m"
  done < <(rows path)

  # Text in workflows, package.json and scripts, now or in any past commit.
  local spec=(-- '.github' 'package.json' '*.sh' '*.yml' '*.yaml' '*.js' '*.mjs' '*.py')
  while IFS="$TAB" read -r pat conf camp note; do
    [ -n "$pat" ] || continue
    local m; m="$(git -C "$repo" grep -n -I -E -e "$pat" "${spec[@]}" 2>/dev/null | head -5)"
    [ -n "$m" ] && while IFS= read -r hit; do
      finding "$conf" "$camp" "now in ${hit%%:*}: $(printf '%s' "${hit#*:}" | cut -c1-100)" "$note"
    done <<< "$m"
    m="$(git -C "$repo" log --all -G"$pat" --format='%h %aI %s' "${spec[@]}" 2>/dev/null | head -5)"
    [ -n "$m" ] && while IFS= read -r c; do
      finding "$conf" "$camp" "in history, commit $c" "$note"
    done <<< "$m"
  done < <(rows content)

  # Branches, local and remote-tracking, and on the remote itself.
  local branches; branches="$( (git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads refs/remotes
    git -C "$repo" ls-remote --heads origin 2>/dev/null | sed 's#.*refs/heads/##') | sed 's#^[^/]*/##; s#^origin/##' | sort -u)"
  while IFS="$TAB" read -r pat conf camp note; do
    [ -n "$pat" ] || continue
    local m; m="$(printf '%s\n' "$branches" | grep -E "$pat")"
    [ -n "$m" ] && while IFS= read -r b; do finding "$conf" "$camp" "branch $b" "$note"; done <<< "$m"
  done < <(rows branch)

  # Actions known to be compromised, and Actions pinned to a movable tag.
  while IFS="$TAB" read -r pat conf camp note; do
    [ -n "$pat" ] || continue
    local m; m="$(git -C "$repo" grep -n -E -e "uses:[[:space:]]*['\"]?$pat" -- '.github/workflows' 2>/dev/null)"
    [ -n "$m" ] && while IFS= read -r hit; do
      finding "$conf" "$camp" "${hit%%:*} uses $(printf '%s' "$hit" | grep -Eo "$pat[^[:space:]'\"]*")" "$note"
    done <<< "$m"
  done < <(rows action)
  local unpinned; unpinned="$(git -C "$repo" grep -h -E -o "uses:[[:space:]]*['\"]?[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[^[:space:]'\"]+" -- '.github/workflows' 2>/dev/null \
    | sed -E "s/uses:[[:space:]]*['\"]?//" | grep -Ev '@[0-9a-f]{40}$' | sort -u)"
  if [ -n "$unpinned" ]; then
    finding low "Actions" "$(printf '%s\n' "$unpinned" | wc -l | tr -d ' ') Action reference(s) pinned to a tag or branch, which its owner (or a thief) can move" \
      "$(printf '%s' "$unpinned" | tr '\n' ' ' | cut -c1-200)"
  fi

  # A workflow or package.json change undone within five minutes: the wfx pattern.
  local sw; sw="$(git -C "$repo" log --all --reverse --format="%h${TAB}%at${TAB}%s" -- .github package.json 2>/dev/null | awk -F'\t' '
    prev_t != "" && $2 - prev_t >= 0 && $2 - prev_t <= 300 && ($3 ~ /^Revert/ || $3 ~ /^ci: (restore|cleanup)$/) {
      printf "%s\t%s\t%s\t%s\n", prev_h, prev_s, $1, $2 - prev_t }
    { prev_h=$1; prev_t=$2; prev_s=$3 }')"
  [ -n "$sw" ] && while IFS="$TAB" read -r h1 s1 h2 secs; do
    finding medium "wfx pattern" "workflow commit $h1 \"$s1\" reverted by $h2 ${secs}s later" "Read both commits: wfx pushes its payload, then reverts it to hide the run."
  done <<< "$sw"

  [ $((n_high+n_medium+n_low)) -gt "$before" ] || echo "  nothing found"
}

for r in "${repos[@]+"${repos[@]}"}"; do check_repo "$r"; done

# ---------------------------------------------------------------------------------------------
if [ -n "$account" ]; then
  echo "== GitHub account $account"
  if ! have gh || ! gh auth status >/dev/null 2>&1; then
    echo "  gh isn't installed or signed in; skipped (gh auth login)"
  else
    before=$((n_high+n_medium+n_low))
    # Commit messages, searched once across the account (default branches GitHub has indexed).
    while IFS="$TAB" read -r pat conf camp note; do
      [ "$conf" = low ] && continue
      msg="$(printf '%s' "$pat" | sed 's/^\^//; s/\$$//')"
      printf '%s' "$msg" | grep -q '[][()|*+?{}\\]' && continue   # only literal messages can be searched
      m="$(gh search commits "\"$msg\"" --owner "$account" --limit 100 --json repository,sha \
        --jq '.[] | .repository.fullName + " " + .sha[0:7]' </dev/null 2>/dev/null)"
      [ -n "$m" ] && while read -r rp sha; do finding "$conf" "$camp" "commit $sha \"$msg\" in $rp" "$note"; done <<< "$m"
      m="$(gh search prs "\"$msg\"" --owner "$account" --match title --limit 100 --json repository,number,state \
        --jq '.[] | .repository.nameWithOwner + " #" + (.number|tostring) + " " + .state' </dev/null 2>/dev/null)"
      [ -n "$m" ] && while read -r rp num st; do finding "$conf" "$camp" "pull request $rp $num ($st) titled \"$msg\"" "$note"; done <<< "$m"
    done < <(rows commit)

    repolist="$(gh repo list "$account" --limit 1000 --json nameWithOwner,defaultBranchRef \
      --jq '.[] | .nameWithOwner + " " + (.defaultBranchRef.name // "")' </dev/null 2>/dev/null)"
    [ -n "$repolist" ] && while read -r rp def; do
      bl="$(gh api "repos/$rp/branches?per_page=100" --paginate --jq '.[].name' </dev/null 2>/dev/null)"
      while IFS="$TAB" read -r pat conf camp note; do
        m="$(printf '%s\n' "$bl" | grep -E "$pat")"
        [ -n "$m" ] && while IFS= read -r b; do finding "$conf" "$camp" "branch $b in $rp" "$note"; done <<< "$m"
      done < <(rows branch)
      if [ -n "$def" ]; then
        tree="$(gh api "repos/$rp/git/trees/$def?recursive=1" --jq '.tree[].path' </dev/null 2>/dev/null)"
        while IFS="$TAB" read -r pat conf camp note; do
          m="$(printf '%s\n' "$tree" | grep -E "$pat")"
          [ -n "$m" ] && while IFS= read -r p; do finding "$conf" "$camp" "file $p in $rp" "$note"; done <<< "$m"
        done < <(rows path)
      fi
      # Deploy keys and webhooks: a quiet way back in. Listed for review, not judged.
      gh api "repos/$rp/keys" </dev/null --jq '.[] | "deploy key \"" + .title + "\" added " + .created_at + (if .read_only then " (read-only)" else " (can push)" end)' 2>/dev/null \
        | while IFS= read -r k; do echo "  [INFO] $rp: $k"; done
      gh api "repos/$rp/hooks" </dev/null --jq '.[] | "webhook to " + .config.url + " added " + .created_at' 2>/dev/null \
        | while IFS= read -r k; do echo "  [INFO] $rp: $k"; done
    done <<< "$repolist"
    [ $((n_high+n_medium+n_low)) -gt "$before" ] || echo "  nothing found"
  fi
fi

# ---------------------------------------------------------------------------------------------
echo "== Summary: $n_high high, $n_medium medium, $n_low low (indicators reviewed $(grep -m1 '^# Last reviewed:' "$data" | sed 's/# Last reviewed: //; s/\..*//'))"
if [ $((n_high+n_medium)) -gt 0 ]; then
  echo "Read every finding before acting. For a confirmed one, follow 'Responding to a finding' in this skill's SKILL.md: lock the account and rotate secrets first."
  exit 1
fi
exit 0

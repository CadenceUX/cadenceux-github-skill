#!/usr/bin/env bash
# Looks for client material and secrets in a skill before it goes on GitHub.
#
#   bash scripts/scan_for_client_material.sh <skill-folder> [--history] [term ...]
#
# Scans every file Git would commit (tracked, plus untracked files not in .gitignore). If the
# folder isn't a Git repo yet, scans every file under it. --history also searches every past
# commit, which is what matters before a repo goes public. Each extra term (a client name,
# hostname, account name or the leaked secret itself) is matched case-insensitively as plain
# text. Needs git and grep (macOS, Linux, Git Bash on Windows).
#
# Exit 0: nothing found. Exit 1: findings to review. Exit 2: usage error.
# A clean result is not a guarantee: it only knows the patterns below and the terms you pass.

set -uo pipefail

usage() { echo "usage: bash scripts/scan_for_client_material.sh <skill-folder> [--history] [term ...]" >&2; exit 2; }

dir="${1:-}"; [ -n "$dir" ] || usage; shift
[ -d "$dir" ] || { echo "scan: $dir is not a folder" >&2; exit 2; }
history=0; terms=()
for a in "$@"; do
  if [ "$a" = "--history" ]; then history=1; else terms+=("$a"); fi
done

cd "$dir" || exit 2

# Patterns for things that should never be published. Each is an extended regex, matched
# case-insensitively. Kept broad on purpose: a false positive costs a glance, a miss costs a leak.
patterns=(
  'fmnet:/'                                          # hosted FileMaker file address
  'fmp://[^ ]*@'                                     # fmp URL with an account in it
  '(password|passwd|pwd)[[:space:]]*[:=]'            # password assignments
  'Re-Login[^]]*Password'                            # Re-Login step with a password
  'Account Name:[[:space:]]*"[^"$]'                  # literal account in a script step
  '(api[_-]?key|secret|token)[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9_-]{12,}'
  'sk-ant-[A-Za-z0-9_-]{10,}'                        # Anthropic API key
  'gh[pousr]_[A-Za-z0-9]{20,}'                       # GitHub token
  'AKIA[0-9A-Z]{16}'                                 # AWS access key
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b'                  # IPv4 address
)
for t in "${terms[@]+"${terms[@]}"}"; do
  # Escape regex metacharacters so each term is matched literally.
  patterns+=("$(printf '%s' "$t" | sed 's/[][\.*^$+?(){}|/]/\\&/g')")
done

found=0
is_repo=0; git rev-parse --is-inside-work-tree >/dev/null 2>&1 && is_repo=1

# Files that must never be published, by name.
if [ $is_repo -eq 1 ]; then
  files="$(git ls-files -co --exclude-standard)"
else
  files="$(find . -type f ! -path './.git/*' | sed 's|^\./||')"
fi
bad_files="$(printf '%s\n' "$files" | grep -Ei '\.(fmp12|fp7|fmp12\.[a-z]+|env|pem|key|p12|pfx)$|(^|/)\.env(\.|$)|saxml|ddr' | grep -v '\.env\.example$' || true)"
if [ -n "$bad_files" ]; then
  echo "== Files that should not be committed (add them to .gitignore):"
  printf '%s\n' "$bad_files" | sed 's/^/  /'
  found=1
fi

# Email addresses are checked on their own so the allowed ones (the GitHub noreply address,
# noreply@ senders, example.com/org placeholders) can be dropped without hiding a real address
# on the same line.
email_re='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
allowed_email='users\.noreply\.github\.com|@example\.(com|org)( |$)|[: ]noreply@'

# Content of the files Git would commit.
echo "== Current files:"
hits=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  grep -Iq . "$f" 2>/dev/null || continue           # skip binaries and empty files
  for p in "${patterns[@]}"; do
    out="$(grep -EinH -e "$p" "$f" 2>/dev/null || true)"
    [ -n "$out" ] && hits="$hits$out"$'\n'
  done
  out="$(grep -EnoH -e "$email_re" "$f" 2>/dev/null | grep -Eiv "$allowed_email" | sed 's/$/  (email)/' || true)"
  [ -n "$out" ] && hits="$hits$out"$'\n'
done <<< "$files"
if [ -n "$hits" ]; then
  printf '%s' "$hits" | sort -u | sed 's/^/  /'
  found=1
else
  echo "  nothing found"
fi

if [ $history -eq 1 ]; then
  echo "== Every commit (--history):"
  if [ $is_repo -eq 0 ] || ! git rev-parse -q --verify HEAD >/dev/null; then
    echo "  no commits yet"
  else
    hist=""
    for p in "${patterns[@]}"; do
      out="$(git log --all -p --no-color -i -G"$p" --format='commit %h %s' 2>/dev/null \
        | grep -Ei -e '^commit ' -e "^[+-].*($p)" \
        | awk '/^commit /{c=$0; next} {print c ": " $0}' || true)"
      [ -n "$out" ] && hist="$hist$out"$'\n'
    done
    out="$(git log --all -p --no-color --format='commit %h %s' 2>/dev/null \
      | awk '/^commit /{c=$0; next} /^[+-]/{ s=$0; while (match(s, /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z][A-Za-z]+/)) { print c ": " substr(s, RSTART, RLENGTH) "  (email)"; s=substr(s, RSTART+RLENGTH) } }' \
      | grep -Eiv "$allowed_email" || true)"
    [ -n "$out" ] && hist="$hist$out"$'\n'
    if [ -n "$hist" ]; then
      printf '%s' "$hist" | sort -u | sed 's/^/  /'
      found=1
    else
      echo "  nothing found"
    fi
  fi
fi

if [ $found -eq 1 ]; then
  echo "Review every line above. Generalise or remove client material; rotate any real credential."
  exit 1
fi
echo "No findings. Still read the files yourself: this only knows its patterns and your terms."
exit 0

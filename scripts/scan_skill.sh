#!/usr/bin/env bash
# Checks a Claude skill for signs it could harm you before (or after) you install it: a
# downloaded .zip or .skill file, a skill folder, or every skill and plugin already installed.
#
#   bash scripts/scan_skill.sh <file.zip|file.skill|folder> [...]
#   bash scripts/scan_skill.sh --installed [--project <folder>]
#
# Archives are listed before anything is extracted, then unpacked into a temporary folder that
# is deleted afterwards; nothing is installed or run. Each file is read by kind:
#   code          scripts, package.json, hooks and MCP config: download-and-run, reverse shells,
#                 reading credential stores, persistence, quarantine removal, data sent to
#                 paste or webhook sites, obfuscation, install hooks
#   instructions  SKILL.md and other markdown: hidden Unicode, prompt-injection phrasing, hidden
#                 HTML comments, frontmatter that pre-approves shell commands or adds hooks; the
#                 code checks too, one level lower
#   data          reference files (JSON, CSV, text): hidden Unicode and known attack indicators
#                 only, so a catalog full of example commands doesn't bury the real findings
# plus the indicators in references/known-attacks.tsv (wfx, Gheist, GhostAction) everywhere.
#
# --installed covers ~/.claude/skills, the project's .claude/skills, every Claude Code plugin in
# ~/.claude/plugins/installed_plugins.json (with its hooks and MCP servers), and the skills the
# Claude desktop app has synced (macOS and Windows). Skills uploaded to Claude.ai in a browser
# aren't on this computer: download them and scan the file.
#
# Needs bash, grep, awk, find; unzip or python3 for archives; perl for the Unicode check (all on
# macOS, Linux and Git Bash for Windows).
# Exit 0: no high or medium findings. Exit 1: findings to read. Exit 2: usage error.
# A clean result is not a guarantee: read any script before letting Claude run it.

set -uo pipefail

usage() { echo "usage: bash scripts/scan_skill.sh <file.zip|file.skill|folder> [...] | --installed [--project <folder>]" >&2; exit 2; }

here="$(cd "$(dirname "$0")" && pwd)"
data="$here/../references/known-attacks.tsv"
[ -f "$data" ] || data="$here/known-attacks.tsv"   # downloaded beside the script
have() { command -v "$1" >/dev/null 2>&1; }
TAB="$(printf '\t')"

installed=0; project="$PWD"; targets=()
while [ $# -gt 0 ]; do
  case "$1" in
    --installed) installed=1; shift ;;
    --project) [ -n "${2:-}" ] || usage; project="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) targets+=("$1"); shift ;;
  esac
done
[ $installed -eq 1 ] || [ ${#targets[@]} -gt 0 ] || usage

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
t_high=0; t_medium=0; t_low=0
n_high=0; n_medium=0; n_low=0

finding() {   # level check where text
  local lv="$1"
  case "$lv" in high) n_high=$((n_high+1));; medium) n_medium=$((n_medium+1));; low) n_low=$((n_low+1));; esac
  printf '  [%s] %s: %s%s\n' "$(printf '%s' "$lv" | tr '[:lower:]' '[:upper:]')" "$2" "$3" "${4:+: $(printf '%s' "$4" | tr -d '\r' | sed 's/^[[:space:]]*//' | cut -c1-110)}"
}
lower() { case "$1" in high) echo medium;; medium) echo low;; *) echo info;; esac; }

# Patterns: level<TAB>check<TAB>extended regex (case-insensitive). Literal words are split with
# brackets ("Launch(Agent|Daemon)s", "/dev/tc[p]/") so this script never matches itself.
code_patterns() { cat <<'EOF'
high	download and run	(curl|wget)[^|;]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da)?sh([[:space:]]|$)
high	download and run	(curl|wget)[^|;]*\|[[:space:]]*(python3?|perl|ruby|node)([[:space:]]|$)
high	download and run	eval[[:space:]]*"?\$\([[:space:]]*(curl|wget)
high	decode and run	base64[[:space:]]+(-d|--decode|-D)[^|]*\|[[:space:]]*(ba|z)?sh
high	decode and run	(eval|exec|Function)[[:space:]]*\(.*(atob|b64decode|Buffer\.from\([^)]*base64)
high	reverse shell	/dev/tc[p]/|bash[[:space:]]+-i[[:space:]]*>&|nc[[:space:]]+(-[a-z]*e[[:space:]]|.*[[:space:]]-e[[:space:]])|socat[[:space:]].*exec:
high	reads credentials	\.ssh/id_[a-z0-9]+|\.aws/credential[s]|\.config/gh/hosts\.ym[l]|gh[[:space:]]+auth[[:space:]]+token|\.docker/config\.jso[n]|\.netr[c]([^a-z]|$)
high	reads credentials	security[[:space:]]+(find-(generic|internet)-password|dump-keychain)|Library/Keychain[s]|Cookies\.binarycookie[s]|/Login Dat[a]|cookies\.sqlit[e]
high	persistence	Launch(Agent|Daemon)s|crontab[[:space:]]+-?[a-z]*|systemctl[[:space:]]+(--user[[:space:]]+)?enable|schtasks[[:space:]]|CurrentVersion\\Ru[n]
high	persistence	>>?[[:space:]]*["']?(~|\$HOME)?/?[^[:space:]]*\.(bashrc|zshrc|bash_profile|zprofile|profile)([[:space:]"']|$)
high	disables protection	xattr[[:space:]]+-[a-z]*d[a-z]*[[:space:]]+com\.apple\.quarantin[e]|spctl[[:space:]]+--master-disabl[e]|Set-MpPreference[[:space:]].*-Disabl[e]
high	sends data out	webhook\.sit[e]|requestbi[n]|pipedream\.ne[t]|ngrok(-free)?\.(io|app)|pastebin\.co[m]|transfer\.s[h]|discord(app)?\.com/api/webhook[s]|hooks\.slack\.com/service[s]|api\.telegram\.org/bo[t]|interact\.s[h]|oast\.(fun|pro|live|site|me)|burpcollaborato[r]
high	deletes your files	rm[[:space:]]+-[a-z]*r[a-z]*[[:space:]]+(-[a-z]+[[:space:]]+)*("?(~|\$HOME)/?"?|/)([[:space:]]|$)
medium	raw IP address	https?://([0-9]{1,3}\.){3}[0-9]{1,3}
medium	install hook	"(pre|post)install"[[:space:]]*:
medium	obfuscated text	[A-Za-z0-9+/]{240,}={0,2}|(\\x[0-9a-fA-F]{2}){24,}
medium	installs packages from a URL	(pip3?|npm|gem)[[:space:]]+install[[:space:]]+[^#]*(https?://|git\+)
low	admin rights	(^|[[:space:];|&])sudo[[:space:]]
low	sends data out	(curl|wget)[^#]*(-d|--data|--data-binary|-F|--upload-file|-T)[[:space:]]
EOF
}
instruction_patterns() { cat <<'EOF'
medium	prompt injection	(^|[^"'A-Za-z])ignore[[:space:]]+(all[[:space:]]+)?(previous|prior|earlier|above|your|the system)[[:space:]]+(instruction|rule|guideline|prompt)s?
medium	prompt injection	(do not|don't|never)[[:space:]]+(tell|inform|mention|reveal|show|alert)[[:space:]]+(this[[:space:]]+(to[[:space:]]+)?)?(to[[:space:]]+)?the[[:space:]]+user([[:space:]]*[.,;:!)"-]|[[:space:]]*$|[[:space:]]+(about|that|what|where|you|anything))
medium	prompt injection	without[[:space:]]+(asking|telling|informing|notifying|alerting)[[:space:]]+the[[:space:]]+user
medium	prompt injection	(disregard|override|bypass|turn off)[[:space:]]+(your|the|any|all)[[:space:]]+(safety|system|security|permission|approval)
medium	prompt injection	(silently|quietly|secretly|covertly)[[:space:]]+(run|execute|send|upload|install|delete|post|copy)
medium	skips approvals	dangerously-skip-permission[s]|bypassPermission[s]
EOF
}

classify() {   # relative path -> code | instructions | data | binary
  local rel="$1" f="$2" base; base="$(basename "$rel")"
  if [ -s "$f" ] && ! grep -Iq . "$f" 2>/dev/null; then echo binary; return; fi
  case "$base" in
    package.json|hooks.json|.mcp.json|Makefile|Dockerfile) echo code; return ;;
  esac
  case "$rel" in
    *.sh|*.bash|*.zsh|*.command|*.py|*.js|*.mjs|*.cjs|*.ts|*.rb|*.pl|*.php|*.ps1|*.psm1|*.bat|*.cmd|*.applescript|*.swift|*.go|*.lua) echo code; return ;;
    scripts/*|*/scripts/*|bin/*|*/bin/*|hooks/*|*/hooks/*) echo code; return ;;
    *.md|*.markdown|*.mdx) echo instructions; return ;;
  esac
  head -c 2 "$f" 2>/dev/null | grep -q '^#!' && { echo code; return; }
  echo data
}

grep_list() {   # list-file(NUL-separated) level-adjust(0|1) root; patterns on stdin
  local list="$1" adjust="$2" root="$3"
  [ -s "$list" ] || { cat >/dev/null; return 0; }
  while IFS="$TAB" read -r lv check pat; do
    [ -n "$pat" ] || continue
    [ "$adjust" = 1 ] && lv="$(lower "$lv")"
    [ "$lv" = info ] && continue
    # One grep per pattern across every file of this kind; at most three hits per file.
    local ci=-i; case "$check" in *"known attack indicator") ci="" ;; esac   # indicators are case-sensitive, as in check_known_attacks.sh
    local m; m="$(xargs -0 grep -H -n $ci -E -e "$pat" -- < "$list" 2>/dev/null | awk -F: '++c[$1] <= 3')"
    if [ "$check" = "raw IP address" ] && [ -n "$m" ]; then
      # Local, private and documentation addresses are normal in setup instructions.
      m="$(printf '%s\n' "$m" | grep -Ev 'https?://(127\.|0\.0\.0\.0|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.|169\.254\.|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.)' || true)"
    fi
    [ -n "$m" ] && while IFS= read -r hit; do
      local file="${hit%%:*}" rest="${hit#*:}"
      finding "$lv" "$check" "${file#"$root"/}:${rest%%:*}" "${rest#*:}"
    done <<< "$m"
  done
}

attack_rows() {   # level<TAB>campaign<TAB>pattern for the content and path indicators
  [ -f "$data" ] || return 0
  grep -v '^#' "$data" | awk -F'\t' -v k="$1" '$1==k { print $3 "\t" $4 ": known attack indicator\t" $2 }'
}

scan_tree() {   # folder label
  local root="$1" label="$2"
  n_high=0; n_medium=0; n_low=0
  echo "== $label"
  local all; all="$(find "$root" \( -type f -o -type l \) ! -path '*/.git/*' 2>/dev/null | sort)"
  local skills; skills="$(printf '%s\n' "$all" | grep -c '/SKILL\.md$')"
  local first; first="$(printf '%s\n' "$all" | grep '/SKILL\.md$' | head -1)"
  local name=""; [ -n "$first" ] && name="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f&&/^name:/{sub(/^name:[[:space:]]*/,"");print;exit}' "$first" 2>/dev/null)"
  echo "  $skills skill(s)${name:+, first: $name}; $(printf '%s\n' "$all" | grep -c .) files"
  if [ "$skills" -eq 0 ]; then
    if [ -f "$root/.claude-plugin/plugin.json" ]; then echo "  [INFO] plugin with no skills (commands, agents, hooks or standards only)"
    else finding medium "not a skill" "$label" "no SKILL.md inside"; fi
  fi

  local code="$work/code.lst" instr="$work/instr.lst" dat="$work/data.lst" text="$work/text.lst"
  : > "$code"; : > "$instr"; : > "$dat"; : > "$text"

  # File names that match known attack indicators, checked once over the whole list.
  local rels; rels="$(printf '%s\n' "$all" | awk -v r="$root/" 'index($0, r) == 1 { print substr($0, length(r) + 1) }')"
  while IFS="$TAB" read -r lv check pat; do
    [ -n "$pat" ] || continue
    local m; m="$(printf '%s\n' "$rels" | grep -E -e "$pat")"
    [ -n "$m" ] && while IFS= read -r p; do finding "$lv" "$check" "$p" "file name matches"; done <<< "$m"
  done < <(attack_rows path)

  local f rel kind
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="${f#"$root"/}"
    # Symbolic links can point anywhere on your disk.
    if [ -L "$f" ]; then finding high "symbolic link" "$rel" "points to $(readlink "$f")"; continue; fi
    kind="$(classify "$rel" "$f")"
    if [ "$kind" = binary ]; then
      local magic; magic="$(head -c 4 "$f" 2>/dev/null | od -An -tx1 | tr -d ' \n')"
      case "$magic" in
        7f454c46*|4d5a*|cafebabe|feedface|feedfacf|cefaedfe|cffaedfe) finding high "compiled program" "$rel" "a skill shouldn't need one; you can't read what it does" ;;
        504b0304*|1f8b*|425a68*|377abcaf*|52617221*) finding medium "archive inside" "$rel" "unpack it and scan it too" ;;
        *) case "$rel" in *.dylib|*.so|*.dll|*.exe|*.pkg|*.dmg|*.jar|*.node) finding high "compiled program" "$rel" "" ;; esac ;;
      esac
      continue
    fi
    case "$(basename "$rel")" in
      .gitignore|.gitattributes|.DS_Store|.mcp.json|.editorconfig|.npmignore|.prettierrc|.eslintrc*) ;;
      .*) finding low "hidden file" "$rel" "" ;;
    esac
    case "$kind" in
      code) printf '%s\0' "$f" >> "$code" ;;
      instructions) printf '%s\0' "$f" >> "$instr" ;;
      *) printf '%s\0' "$f" >> "$dat" ;;
    esac
    printf '%s\0' "$f" >> "$text"
  done <<< "$all"

  # Hidden characters: zero-width, bidirectional overrides, Unicode tag characters (invisible text
  # a model reads but a person doesn't), and a byte-order mark anywhere but the start of a file.
  if have perl && [ -s "$text" ]; then
    local hu; hu="$(xargs -0 perl -CSD -ne 'if (($n{$ARGV} // 0) < 3 && (/([\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{2064}\x{2066}-\x{2069}\x{E0000}-\x{E007F}])/ || ($. > 1 && /(\x{FEFF})/) || /.(\x{FEFF})/)) { printf "%s\t%d\tU+%04X\n", $ARGV, $., ord($1); $n{$ARGV}++ } close ARGV if eof' < "$text" 2>/dev/null)"
    [ -n "$hu" ] && while IFS="$TAB" read -r hf ln cp; do finding high "hidden characters" "${hf#"$root"/}:$ln" "$cp: invisible to you, read by Claude"; done <<< "$hu"
  fi

  grep_list "$text" 0 "$root" < <(attack_rows content)
  grep_list "$code" 0 "$root" < <(code_patterns)
  grep_list "$instr" 0 "$root" < <(instruction_patterns)
  grep_list "$instr" 1 "$root" < <(code_patterns)

  # SKILL.md frontmatter and HTML comments (hidden when rendered, read by Claude).
  local sk; sk="$(printf '%s\n' "$all" | grep '/SKILL\.md$')"
  [ -n "$sk" ] && while IFS= read -r f; do
    rel="${f#"$root"/}"
    local fm; fm="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$f")"
    if printf '%s\n' "$fm" | grep -Eq '(^|[^A-Za-z])Bash([^(A-Za-z]|$)|Bash\(\*\)' \
      && printf '%s\n' "$fm" | grep -Eq '^allowed-tools:|^[[:space:]]*-[[:space:]]*Bash'; then
      finding medium "pre-approved shell" "$rel" "allowed-tools lets the skill run any shell command without asking"
    fi
    printf '%s\n' "$fm" | grep -Eq '^hooks:' && finding medium "skill hooks" "$rel" "frontmatter defines hooks: commands that run automatically"
    local hc; hc="$(grep -n '^[[:space:]]*<!--' "$f" | head -3)"
    [ -n "$hc" ] && while IFS= read -r hit; do
      if printf '%s' "$hit" | grep -Eiq '<!--.*(claude|assistant|ignore|instruction|must|always|never|run|execute|send|user)'; then
        finding medium "hidden comment" "$rel:${hit%%:*}" "${hit#*:}"
      else
        finding low "hidden comment" "$rel:${hit%%:*}" "${hit#*:}"
      fi
    done <<< "$hc"
  done <<< "$sk"

  # What a plugin runs on its own: hooks, and the MCP servers it starts. Listed for review.
  printf '%s\n' "$all" | grep -E '/(hooks|plugin|settings)\.json$|/\.mcp\.json$' | while IFS= read -r f; do
    grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' "$f" 2>/dev/null | sed 's/.*:[[:space:]]*"//; s/"$//' | sort -u | head -10 \
      | while IFS= read -r c; do echo "  [INFO] runs automatically: ${f#"$root"/}: $c"; done
  done

  echo "  -> $n_high high, $n_medium medium, $n_low low"
  t_high=$((t_high+n_high)); t_medium=$((t_medium+n_medium)); t_low=$((t_low+n_low))
}

list_archive() {   # archive -> lines: type<TAB>size<TAB>name  (type l = symlink)
  if have zipinfo; then
    zipinfo -l "$1" 2>/dev/null | awk 'NR>2 && NF>=10 && $1 ~ /^[-dl?]/ { name=$0; sub(/^([^ ]+ +){9}/, "", name); printf "%s\t%s\t%s\n", substr($1,1,1), $4, name }'
  elif have python3; then
    python3 -I -c 'import sys,zipfile,stat
for i in zipfile.ZipFile(sys.argv[1]).infolist():
    m=i.external_attr>>16; t="l" if stat.S_ISLNK(m) else ("d" if i.is_dir() else "-")
    print(f"{t}\t{i.file_size}\t{i.filename}")' "$1"
  else
    return 1
  fi
}

scan_archive() {
  local a="$1"
  echo "== $a (archive)"
  local listing; listing="$(list_archive "$a")" || { echo "  needs unzip (zipinfo) or python3 to read archives; skipped"; return; }
  [ -n "$listing" ] || { finding high "unreadable archive" "$a" "not a zip file, or damaged"; return; }
  n_high=0; n_medium=0; n_low=0
  local bad; bad="$(printf '%s\n' "$listing" | cut -f3 | grep -E '(^|/)\.\.(/|$)|^/|^[A-Za-z]:|\\' | head -5)"
  [ -n "$bad" ] && while IFS= read -r e; do finding high "escapes the folder" "$a" "entry $e would be written outside the skill"; done <<< "$bad"
  local links; links="$(printf '%s\n' "$listing" | awk -F'\t' '$1=="l"{print $3}' | head -5)"
  [ -n "$links" ] && while IFS= read -r e; do finding high "symbolic link" "$a" "entry $e"; done <<< "$links"
  local tops; tops="$(printf '%s\n' "$listing" | cut -f3 | grep -v '^__MACOSX/' | sed 's#/.*##' | sort -u | wc -l | tr -d ' ')"
  [ "$tops" -eq 1 ] || finding low "layout" "$a" "$tops top-level entries; a skill archive should hold one folder"
  printf '%s\n' "$listing" | cut -f3 | grep -q '(^|/)\.claude-plugin/' && echo "  [INFO] contains .claude-plugin/: the Claude app's skill upload rejects it"
  local total count; total="$(printf '%s\n' "$listing" | awk -F'\t' '{s+=$2} END {print s+0}')"; count="$(printf '%s\n' "$listing" | wc -l | tr -d ' ')"
  [ "$total" -le 104857600 ] || finding medium "very large" "$a" "unpacks to $((total/1048576)) MB (possible zip bomb); not extracted"
  [ "$count" -le 200 ] || finding low "many files" "$a" "$count entries; Claude uploads fail above roughly 200"
  local ah=$n_high am=$n_medium al=$n_low
  if [ "$total" -gt 104857600 ]; then t_high=$((t_high+ah)); t_medium=$((t_medium+am)); t_low=$((t_low+al)); return; fi
  local dest; dest="$(mktemp -d "$work/x.XXXX")"
  if have unzip; then unzip -qq -o "$a" -d "$dest" 2>/dev/null
  else python3 -I -c 'import sys,zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$a" "$dest"; fi
  rm -rf "$dest/__MACOSX"
  scan_tree "$dest" "$a (contents)"
  t_high=$((t_high+ah)); t_medium=$((t_medium+am)); t_low=$((t_low+al))
}

scan_target() {
  local t="$1"
  if [ -d "$t" ]; then scan_tree "$(cd "$t" && pwd)" "$t"
  elif [ -f "$t" ]; then scan_archive "$t"
  else echo "== $t"; echo "  not found; skipped"; fi
}

for t in "${targets[@]+"${targets[@]}"}"; do scan_target "$t"; done

if [ $installed -eq 1 ]; then
  roots=""
  for d in "$HOME/.claude/skills" "$project/.claude/skills"; do
    [ -d "$d" ] && for s in "$d"/*/; do [ -f "$s/SKILL.md" ] && roots="$roots${s%/}"$'\n'; done
  done
  reg="$HOME/.claude/plugins/installed_plugins.json"
  if [ -f "$reg" ]; then
    roots="$roots$(grep -o '"installPath"[[:space:]]*:[[:space:]]*"[^"]*"' "$reg" | sed 's/.*:[[:space:]]*"//; s/"$//' | sort -u)"$'\n'
  fi
  for app in "$HOME/Library/Application Support/Claude" "${APPDATA:-/nonexistent}/Claude"; do
    for s in "$app"/local-agent-mode-sessions/skills-plugin/*/*/skills/*/; do
      [ -f "$s/SKILL.md" ] && roots="$roots${s%/}"$'\n'
    done
  done
  roots="$(printf '%s' "$roots" | grep -v '^$' | sort -u)"
  if [ -z "$roots" ]; then
    echo "== Installed: nothing found in the usual places"
  else
    echo "Scanning $(printf '%s\n' "$roots" | wc -l | tr -d ' ') installed skill and plugin folder(s)."
    while IFS= read -r r; do [ -d "$r" ] && scan_tree "$r" "${r/#$HOME/~}"; done <<< "$roots"
  fi
fi

echo "== Summary: $t_high high, $t_medium medium, $t_low low"
if [ $((t_high+t_medium)) -gt 0 ]; then
  echo "Read each finding in context: a reference skill can quote risky commands as documentation. Don't install, or remove, anything you can't explain."
  exit 1
fi
exit 0

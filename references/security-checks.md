# Security checks: known attacks, and skills before you trust them

## Contents
- Checking for known attacks (`check_known_attacks.sh`)
- Reading the findings
- Responding to a finding
- Checking a skill before you install it (`scan_skill.sh`)
- Keeping the indicators current

Both scripts are read-only. They change no file, setting or GitHub object, so run them freely;
everything they report is for the developer to read before anything is changed.

## Checking for known attacks

Stolen GitHub tokens are used to push code that steals the secrets a repo's Actions can read.
The November 2026 **wfx** campaign hit about 4,800 accounts this way; **Gheist** and
**GhostAction** work alike. The commits appear under the victim's own name and are reverted
within seconds, so the repo looks untouched unless you read its full history.

```bash
bash check_known_attacks.sh                                  # tools only
bash check_known_attacks.sh ~/skills/invoice-helper          # plus a local clone
bash check_known_attacks.sh --account username ~/skills/*    # plus every repo the account owns
```

| Part | What it checks |
|---|---|
| Tools | Every `git` on the PATH against the lowest patched version in its release line (an old copy in another folder still counts: other apps may use it); whether git's credential helper points at a program that still exists |
| Each clone | Attack commit messages, file names, payload text and branches across **all history** (`git log --all`), so reverted payloads are found; Actions with known compromises; Actions pinned to a movable tag; a workflow change reverted within five minutes |
| `--account` | The same commit messages and the probe pull-request title searched across the account, every repo's branches and default-branch file names, and each repo's deploy keys and webhooks (listed, not judged) |

`--account` needs `gh` signed in. GitHub's commit search covers default branches it has indexed,
so also scan local clones of anything important.

## Reading the findings

Each finding has a level and the campaign it belongs to:

- **HIGH**: an indicator seen only in an attack (a payload file name, a campaign token, a
  collection server, an unpatched Git). Treat as real until a person has read the commit.
- **MEDIUM**: attack-specific but also used innocently. A commit titled "ci: refresh build
  cache" is normal in many projects; it's the large block appended to a workflow, the dump of
  the secrets context, or the hidden `.ci-` script beside it that confirms it.
- **LOW**: generic (a revert message, a throwaway-looking branch name, Actions on a tag).
  Meaningful only next to a higher finding.

Read the commit before concluding anything: `git show <hash> --stat`, then the diff. Unsigned
commits under the owner's name, pushed minutes apart with a revert, are the wfx shape.

## Responding to a finding

When a person has confirmed a finding, go in this order. Steps 1 and 2 are the developer's own
actions in their browser and cloud consoles; never do them for them.

1. **Lock the account that pushed it**: revoke its personal access tokens, OAuth app grants and
   SSH keys (github.com/settings), sign out other sessions, change the password, and use a
   passkey or authenticator app. Do the same for any bot account that pushed.
2. **Rotate every secret the repo's workflows could read**: repo, organisation and environment
   secrets and variables, cloud keys, package-registry and publishing tokens, AI provider keys.
   Deleting the commit doesn't undo the theft: the attack ran the moment it was pushed.
3. **Check cloud accounts the workflows could reach** for what the attack leaves behind: in AWS,
   IAM access keys created since the attack and any role trust policy opened to every account;
   in Azure, federated credentials named like `wfx-ci-…`; in GCP, impersonation from GitHub's
   identity pool.
4. **Clean the repo**: delete attack branches, close the probe pull request, remove any payload
   file or install hook still present, and republish any package built from an affected commit.
5. **Harden**: require approval for workflow changes (CODEOWNERS on `.github/workflows`), give
   `GITHUB_TOKEN` read-only permissions by default, pin Actions to commit SHAs, and scope cloud
   trust to protected branches.

Treat any computer that ran `npm install` on an affected commit as compromised too.

## Checking a skill before you install it

A skill is instructions Claude follows and, often, scripts Claude runs with your permissions.
Check one from anyone you don't know before installing it, and check what's installed now and
then.

```bash
bash scan_skill.sh invoice-helper.zip                  # a downloaded .zip or .skill
bash scan_skill.sh ~/skills/invoice-helper            # a folder
bash scan_skill.sh --installed                        # everything installed on this computer
```

An archive is listed before anything is unpacked (entries that would land outside the folder,
symbolic links, a zip bomb), then unpacked into a temporary folder that's deleted afterwards.
Nothing is installed or run.

Each file is read by what it is:

| Kind | Checks |
|---|---|
| Scripts, `package.json`, hooks, MCP config | Downloading and running code, decoding and running hidden code, reverse shells, reading SSH keys, cloud credentials, the keychain or browser cookies, adding itself to startup, removing macOS quarantine, sending data to paste, webhook or chat-bot services, raw public IP addresses, install hooks, obfuscated blobs |
| `SKILL.md` and other markdown | Hidden Unicode (zero-width, direction overrides, tag characters: text Claude reads and you can't see), prompt-injection phrasing, HTML comments carrying instructions, `allowed-tools` that pre-approves any shell command, hooks in the frontmatter; plus the script checks, one level lower |
| Reference data | Hidden Unicode and known attack indicators only, so a catalog that quotes commands as documentation isn't flagged |

It also lists, as INFO, every command a plugin runs on its own (hooks, MCP servers): that's
expected for a plugin, but you should know what they are.

`--installed` covers `~/.claude/skills`, the current project's `.claude/skills`, every Claude
Code plugin in `~/.claude/plugins/installed_plugins.json`, and the skills the Claude desktop app
has synced (macOS and Windows). Skills uploaded to Claude.ai in a browser live on Anthropic's
servers: download one from Customize → Skills and scan the file.

**When it finds something:** read the line in context. A skill that teaches shell scripting
can mention a risky command honestly; a skill whose own script reads your SSH keys and sends them to a
webhook can't be explained. Don't install, or uninstall (`claude plugin uninstall`, or remove it
in Customize → Skills), anything whose finding you can't account for, and tell its author.

## Keeping the indicators current

Both scripts read `references/known-attacks.tsv`: one indicator per row (commit message,
branch, file path, payload text, compromised Action, or patched Git version) with its
confidence, campaign and a note. New campaigns are a data change, not a script change. The file
records its review date and sources; re-check them on every release of this skill, because
attack indicators change within weeks. Literal strings are written with one character in
brackets so the scanners never match their own data.

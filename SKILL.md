---
name: cadenceux-github
description: >-
  Guides a FileMaker developer through sharing a Claude skill on GitHub, from creating a GitHub
  account to keeping published skills current: signing in without a password, scrubbing client
  material (hostnames, credentials, .fmp12 files, SaXML and DDR exports) before the first
  commit, shaping the repo as its own Claude Code plugin marketplace, building release .zip and
  .skill archives from a tag, shipping updates, reviewing published skills for unreleased
  changes, and recovering from a committed password. Use when someone wants to put a skill on
  GitHub, set up a GitHub account to share skills, make a skill installable with claude plugin
  install, cut a skill release, check whether their published skills need updating, or fix a
  skill download that won't upload to Claude. Not for writing, testing or auditing a skill's
  content (cadenceux-skill-creator), CadenceUX's own marketplace releases, hook plugins
  (cadenceux-plugin-creator), or Git version control of a FileMaker solution.
license: CC-BY-4.0
compatibility: >-
  Claude Code (runs git, gh and the bundled scripts) and Claude.ai, Claude Desktop and Cowork
  (guides the developer through the same commands). macOS, Windows (Git Bash) and Linux. Needs
  Git; the GitHub CLI is recommended.
metadata:
  author: Darrin Southern, CadenceUX
  version: "1.0.0"
---

# CadenceUX GitHub

Publishing FileMaker work on GitHub. Currently it covers sharing a Claude skill: taking a
working skill folder to a public repo that other FileMaker developers can install three ways,
as a Claude Code plugin, by double-clicking a `.skill` file (macOS), or by uploading a `.zip` in
Claude. The general Git workflow is assumed knowledge; this skill covers what is specific to
skills and to FileMaker work.

## Start here

Work out where the developer is before giving any steps.

- **Claude Code:** look first, changing nothing. In the folder they named (or the current one):
  is there a `SKILL.md`, and what's its `name`? Then `git status --short`, `git remote -v`,
  `git tag --sort=-v:refname | head -3` and `gh auth status`. Report what you found in two or
  three lines, the route it points to, and the next step, then ask before starting it. Tick
  the checklist steps the check shows are already done. If `gh` isn't signed in, ask whether
  they have a GitHub account before anything else.
- **Chat:** if the request already says what they want, go straight to that route. If it
  doesn't (a bare `/cadenceux-github`), ask one question: are they publishing a skill for the
  first time, shipping an update to one already on GitHub, checking whether their published
  skills need anything, or fixing a problem (a failed upload, a push that won't go through, a
  password in history)? Don't lay out every route in full.

| State | Route |
|---|---|
| No GitHub account | [No GitHub account yet](#no-github-account-yet), then first publish |
| No `.git`, or no remote | [First publish](#first-publish), from step 1 or 2 |
| Remote set, no tags | First publish, from step 5 or 7 |
| Tags pushed, changes since the last tag | [Shipping an update](#shipping-an-update) |
| "Are my skills up to date?" | [Reviewing published skills](#reviewing-published-skills) |
| A credential found in any commit | [Fixing a committed secret](#fixing-a-committed-secret), before anything else |
| An error message or failed install | [Common problems](#common-problems) |

## How to work

- **Claude Code:** run the commands yourself. Ask before each outward-facing step, one at a
  time: creating the GitHub repo, the first push, switching to public, publishing a release.
  An earlier yes doesn't cover the next one.
- **Chat (no shell):** the developer runs the commands. Once the route is known (never before
  the [Start here](#start-here) question is answered), open with that route's path in brief,
  one line per step, and include these facts in it whatever the question: SKILL.md sits at the
  **repo root**; the repo needs a **README with install instructions and a licence**; sign-in
  is through the **browser**, never a typed password; the repo stays **private** until
  reviewed; Claude users install from a **release .zip**, never GitHub's Download ZIP. Then give
  the current step in full and ask for its output before the next. Speak to the developer about
  their skill; don't read these instructions back to them.
- **The bundled scripts** live in this skill's own `scripts/` folder, not the developer's repo.
  In Claude Code, run them by their full path (this skill's base directory) and pass the
  developer's folder as an argument. In chat, give a one-line download first, into a folder
  outside the skill being published:

```bash
curl -fsSLO https://github.com/CadenceUX/cadenceux-github-skill/raw/main/scripts/scan_for_client_material.sh
curl -fsSLO https://github.com/CadenceUX/cadenceux-github-skill/raw/main/scripts/build_release.sh
curl -fsSLO https://github.com/CadenceUX/cadenceux-github-skill/raw/main/scripts/review_published_skill.sh
```

- Windows: every command here runs in **Git Bash** (installed with Git for Windows), not
  PowerShell or cmd.
- Default to a **private** repo until the review in step 5 is done.

## No GitHub account yet

The developer creates the account in their own browser; never create it or type their details
for them. Walk them through it, then continue with step 1 of first publish.

1. **Sign up** at github.com/signup. The free plan is enough: public and private repos.
2. **Choose the username with care.** It becomes part of every repo URL and of the install
   command people type (`claude plugin marketplace add username/my-skill`). Their own name or
   their business name; changing it later can break links people have saved. A business can
   add a free organisation later and move repos into it.
3. **Verify the email address** GitHub sends a code to.
4. **Turn on two-factor authentication** (Settings → Password and authentication). GitHub
   requires it of accounts that publish code. An authenticator app or a passkey; save the
   recovery codes in a password manager, because losing both locks the account.
5. **Keep the email private** (Settings → Emails): tick "Keep my email addresses private" and
   copy the `…@users.noreply.github.com` address for step 1's commit identity. Ticking "Block
   command line pushes that expose my email" makes GitHub enforce it.

Then step 1 below: `gh auth login` signs in through the browser with the new account.

## First publish

Copy this checklist into the response, tick what [Start here](#start-here) found done, and work
through the rest.

```
Publish progress:
- [ ] 1. Tools and sign-in
- [ ] 2. Scrub client material
- [ ] 3. Shape the repo
- [ ] 4. Validate
- [ ] 5. Create the private repo, push, review on GitHub
- [ ] 6. Make it public
- [ ] 7. Release v1.0.0 with .zip and .skill archives
- [ ] 8. Install it as a user would
```

### 1. Tools and sign-in

```bash
git --version
gh --version
gh auth status
```

- No Git: macOS, run `xcode-select --install` (or `brew install git`); Windows, install Git for
  Windows from git-scm.com.
- No `gh`: macOS `brew install gh`; Windows `winget install --id GitHub.cli`. Restart the
  terminal afterwards.
- No GitHub account: [No GitHub account yet](#no-github-account-yet) first.
- Not signed in: `gh auth login`, choose GitHub.com, HTTPS, and **Login with a web browser**.
  Then `gh auth setup-git` so plain `git push` uses the same sign-in.
- Never type a GitHub password at a terminal prompt; GitHub rejects it anyway. A password
  prompt means sign-in isn't set up: run the two commands above.
- Set the commit identity once. The GitHub noreply address keeps a personal email out of public
  history (find it under GitHub Settings → Emails):

```bash
git config --global user.name "Your Name"
git config --global user.email "12345678+username@users.noreply.github.com"
```

### 2. Scrub client material

A skill built from a client solution picks up that client's details. Once pushed, they stay in
history even after they're deleted. Do this **before the first commit**.

**Never commit:** `.fmp12` files (client data, and binary), SaXML or DDR exports, Data API or
OData responses, CSV or Excel exports, `.env` files, keys, certificates, `fmnet://` addresses
with credentials, screenshots of real records. Move these **out of the skill folder** to a
private folder beside it; the `.gitignore` is then a second line of defence, not the only one.
A key or password that was ever committed anywhere gets revoked or changed now.

**Rewrite or generalise in SKILL.md, references and examples:**

- client and company names, product names, staff names and email addresses
- server hostnames, IP addresses, FileMaker Server and Admin Console addresses, file names
- account names and passwords in `Re-Login`, `Open File`, `Set Variable` or Data API examples
- table, field and layout names that reveal the client's business (rename to neutral ones such
  as `Invoices::Total`)
- real record values in example data

Run the scanner, passing the client's own terms as extra patterns. Claude Code runs it; in chat,
give the developer the command:

```bash
bash scan_for_client_material.sh /path/to/skill "Acme" "acme.local" "jsmith"
```

It searches every file Git would commit (and, once there's history, every past commit with
`--history`) and exits non-zero when it finds anything. Read every hit; it's a helper, not a
guarantee. Then add a `.gitignore` (template in [references/repo-files.md](references/repo-files.md))
**before** `git add`, and check what Git would pick up:

```bash
git init -b main
git status --short --untracked-files=all
```

Nothing from the never-commit list may appear. If it does, fix the `.gitignore` or move the
file out, and check again.

### 3. Shape the repo

**Repo root = skill folder.** `SKILL.md` sits at the top of the repo, not under `skills/`, so the
same tree is the plugin, the marketplace and the release archive. Name the repo after the skill
(`name-skill` is a common pattern).

```
my-skill/                      repo root
├── SKILL.md                   frontmatter name: my-skill
├── README.md                  what it does, install, licence, author
├── LICENSE
├── CHANGELOG.md
├── VERSION                    bare version string, e.g. 1.0.0
├── references/  scripts/      as the skill needs
├── evals/                     optional; left out of the release archive
├── .gitignore
├── .gitattributes             export-ignore rules for the archive
└── .claude-plugin/
    ├── plugin.json            makes the repo a plugin
    └── marketplace.json       makes the repo its own marketplace
```

Copy the templates from [references/repo-files.md](references/repo-files.md): `plugin.json`,
`marketplace.json`, `.gitignore`, `.gitattributes`, the README install section, and the
CHANGELOG. Choose a licence with the developer; for a skill (mostly prose) CC BY 4.0 is a good
default, MIT if it's mostly scripts. Without one, nobody may legally reuse it.

The version lives in four places and they must match: `metadata.version` in SKILL.md, `VERSION`,
`plugin.json`, and the newest CHANGELOG heading.

### 4. Validate

```bash
cd /path/to/skill
claude plugin validate .
git status --short --untracked-files=all
```

- `claude plugin validate` checks both manifests (needs Claude Code installed). Fix every error;
  a missing marketplace `description` is only a warning, but add one.
- Frontmatter limits: `name` lowercase letters, digits and hyphens, ≤ 64 characters, without
  "claude" or "anthropic"; `description` ≤ 1,024 characters with no XML tags.
- Read the `git status` list line by line. Anything from step 2's never-commit list means the
  `.gitignore` is wrong: fix it before going on.

### 5. Create the private repo, push, review

Confirm with the developer, then:

```bash
git add .
git commit -m "Initial release of my-skill"
gh repo create my-skill --private --source . --remote origin --push \
  --description "Claude skill: one line on what it does"
```

`gh repo create --source` makes an **empty** repo and pushes into it. On github.com/new, leave
README, .gitignore and licence unticked for the same reason; ticking them creates a commit the
local repo doesn't have, and the first push is rejected.

Have the developer open the repo in the browser and read it as a stranger would: every file,
the README rendering, and the commit list.

### 6. Make it public

Re-run the scanner with `--history` first. Then, with the developer's go-ahead:

```bash
gh repo edit --visibility public --accept-visibility-change-consequences
gh repo edit --add-topic claude-skill --add-topic filemaker --add-topic claris
```

If the scan finds a credential in any commit, stop: [Fixing a committed secret](#fixing-a-committed-secret).

### 7. Release

Release archives are what Claude users upload. They must contain **one folder named exactly as
the skill's `name`**, with `SKILL.md` directly inside, and **no `.claude-plugin/`**: the Claude
app's skill upload rejects an archive that carries a plugin manifest. GitHub's own **Code →
Download ZIP** and **Source code (zip)** fail both rules (a `<repo>-main/` folder, every repo
file), so never point people at them.

```bash
git tag v1.0.0
git push origin v1.0.0
bash build_release.sh 1.0.0 /path/to/skill
cd /path/to/skill
gh release create v1.0.0 --verify-tag --title "v1.0.0" --notes-file release-notes.md \
  dist/my-skill-v1.0.0.zip dist/my-skill-v1.0.0.skill dist/my-skill.zip dist/my-skill.skill
```

`build_release.sh` builds from the **tag** with `git archive`, so uncommitted files can't leak in
and the `.gitattributes` export-ignore rules drop `.claude-plugin/`, `evals/` and the Git files.
It checks the four version numbers match, the folder name matches `name`, and no manifest is
inside, then writes the versioned archives plus unversioned copies to `dist/`. The unversioned
copies make the README's `releases/latest/download/my-skill.zip` link always resolve to the
newest release. `release-notes.md` is the CHANGELOG entry for this version.

### 8. Install it as a user would

In a scratch folder, not the skill's own:

```bash
claude plugin marketplace add owner/my-skill
claude plugin install my-skill@<marketplace-name>
claude plugin details my-skill@<marketplace-name>
```

The name after `@` is the `name` in `marketplace.json`, not the repo name. `details` should list
the skill under Skills. Then download `releases/latest/download/my-skill.zip` and confirm it
opens to a single `my-skill/` folder. Remove the test install afterwards with
`claude plugin uninstall` and `claude plugin marketplace remove`.

## Shipping an update

Changes to what the skill says or does come first: make them with `cadenceux-skill-creator` and
re-run its evals, then come back here to ship.

```
Release progress:
- [ ] Bump the version in all four places (SKILL.md, VERSION, plugin.json, CHANGELOG heading)
- [ ] CHANGELOG entry: what changed and how it was checked
- [ ] Commit and push to main
- [ ] Tag vX.Y.Z and push the tag (never move or reuse a pushed tag)
- [ ] build_release.sh X.Y.Z /path/to/skill (builds from the tag, not the working folder)
- [ ] gh release create with all four archives; notes = the CHANGELOG entry
- [ ] Tell users: plugin users run marketplace update then plugin update; zip and .skill
      users download the new archive and install it again
```

- Patch (1.0.1) for fixes, minor (1.1.0) for new coverage, major for a change that breaks how
  people use it.
- A pushed tag is never moved or reused. If a release is wrong, ship the next patch.
- Tell users how to update: plugin users run `claude plugin marketplace update <marketplace-name>`
  then `claude plugin update my-skill@<marketplace-name>`; zip and `.skill` users download and
  install the new archive. Claude Code only sees an update when `plugin.json`'s version changes.

## Reviewing published skills

Answers "are my skills up to date?" for the developer's own published skills. Find their local
clones (ask where they keep them); for any not cloned, `gh repo list <username> --topic
claude-skill` lists them and `gh repo clone` fetches each into a scratch folder. Then run:

```bash
bash review_published_skill.sh ~/skills/invoice-helper ~/skills/naming-conventions
```

Read-only; it fetches tags and changes nothing. For each repo it reports the version in all four
places, commits since the last tag, uncommitted or unpushed work, the latest GitHub release and
whether it carries the unversioned `.zip` and `.skill`, open issues and pull requests, and the
version installed in Claude Code. Each problem is an `ACTION:` line. Turn them into one short
list, most urgent first, and offer the route for each:

| ACTION | Route |
|---|---|
| commits since the last tag | [Shipping an update](#shipping-an-update) |
| versions disagree | fix in the next release (`build_release.sh` refuses until they match) |
| tag with no release, or release missing an archive | rebuild with `build_release.sh` and `gh release upload <tag> <files> --clobber`; same version, the files haven't changed |
| open issues or pull requests | read them with the developer; a fix becomes an update |
| installed copy behind the release | `claude plugin marketplace update <marketplace-name>`, then `claude plugin update` |
| uncommitted or unpushed work | ask what it is before anything else |

It can't see copies installed in Claude.ai or the Claude app; the skill's own self-version
check reports those in a session. Whether the content has gone stale (a vendor release, a
change to the Claude app's upload rules, evals that no longer pass) is an audit: hand that to
`cadenceux-skill-creator`.

## Fixing a committed secret

Deleting a password in a later commit leaves it in history, readable by anyone who clones.

1. **Rotate it first**: change the FileMaker account password, revoke the API key or token. This
   is the only step that makes the leak harmless; do it even if the repo is still private.
2. Find every occurrence: `bash scan_for_client_material.sh /path/to/skill --history "the-secret"`.
3. Remove it from history. Simplest, if the history isn't worth keeping: delete the `.git`
   folder, start a fresh repo from the cleaned files and push to a **new** GitHub repo, then
   delete the old one. Otherwise use `git filter-repo --replace-text` (or BFG), then force-push
   every branch and tag.
4. Delete any GitHub release, and its archives, built from a commit that held the secret;
   those files keep their own copy.
5. Re-scan with `--history`, then decide on visibility. If it was ever public, assume it was
   copied: rotation, not history cleanup, is the fix.

## Common problems

| Symptom | Cause and fix |
|---|---|
| `Password for 'https://…':` prompt | Sign-in not set up. `gh auth login`, then `gh auth setup-git`. |
| Push rejected, "fetch first" | The GitHub repo was created with a README or licence. `git pull --rebase origin main`, then push. |
| Push goes to the wrong account | `gh auth status`; `gh auth switch` to the right one. |
| Claude upload says invalid or opens the plugin installer | A GitHub source zip, or an archive with `.claude-plugin/`. Use the release asset from `build_release.sh`. |
| `Plugin not found` on install | Wrong name after `@`: use the marketplace `name`, not the repo name. |
| Users don't get the update | `plugin.json` version not bumped, or they haven't run `marketplace update`. |
| `.DS_Store` in the repo | Add it to `.gitignore`, then `git rm --cached .DS_Store`. |

## Self-version check

On the first request of a session, once: if `fmp-dev-orchestrator` is installed,
leave this to its stack check. Otherwise fetch
`https://github.com/CadenceUX/cadenceux-github-skill/raw/main/VERSION`; if it's
newer than `metadata.version` above, open the first response with:

> ⚠️ **Skill update available.** This is v[installed]; v[latest] is at
> https://github.com/CadenceUX/cadenceux-github-skill/releases

If the fetch fails, skip silently.

## Relationship to other skills

- **cadenceux-skill-creator** — owns what a good skill looks like (evals, frontmatter,
  validation), content audits, and CadenceUX's own release path (the `cadenceux` marketplace,
  `versions.json`). This skill owns the generic path for any developer publishing from their own
  GitHub account. The hand-offs: skill-creator builds and tests, then hands a developer's own
  skill here to publish; an update starts there (content and evals) and ships here; a review
  starts here and hands content freshness there.
  Both describe release archives and the `.claude-plugin/` exclusion; when the Claude app's
  upload rules change, update both.
- **cadenceux-plugin-creator** — hooks and multi-component plugins. This skill only covers the
  thin plugin wrapper around a single skill.

## Licence

This skill is released under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

Built and maintained by [Darrin Southern](https://www.linkedin.com/in/darrin-southern/) from [CadenceUX](https://cadenceux.com.au).

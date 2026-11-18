# Changelog

## 1.1.0 — 2026-11-18

### Added

- **Security checks** (`references/security-checks.md`, new SKILL.md route and section):
  - `scripts/check_known_attacks.sh` checks every `git` on the PATH against the November 2026
    security fixes, git's credential helper, local clones (all history, so reverted payloads
    are found) and, with `--account`, every repo an account owns, for the wfx, Gheist and
    GhostAction campaigns, compromised Actions (tj-actions, reviewdog, Trivy) and Actions
    pinned to movable tags. Read-only.
  - `scripts/scan_skill.sh` checks a downloaded `.zip` or `.skill` (listed before unpacking:
    path escapes, symlinks, zip bombs), a skill folder, or every installed skill and plugin
    (`--installed`: `~/.claude/skills`, the project's skills, Claude Code plugins and the
    Claude desktop app's synced skills). Scripts are checked for download-and-run, reverse
    shells, credential reads, persistence, quarantine removal and data sent to webhook or
    paste services; markdown for hidden Unicode, prompt injection, hidden comments and
    pre-approved shell access; reference data only for hidden Unicode and attack indicators.
  - `references/known-attacks.tsv`: the indicators both scripts read, with confidence,
    campaign, note, sources and review date, so new campaigns are a data change.
  - Responding to a finding: lock the pushing account, rotate every secret the workflows could
    read, check cloud accounts for what the attack leaves, clean, harden.
- **Retiring a published skill**: archive by default; delete only on an explicit request, with
  the `delete_repo` scope; update every page that mentions it.
- **Requirements** section.

### Changed

- `scan_for_client_material.sh` skips reserved placeholders (`127.x`, `0.0.0.0`, the
  documentation IP ranges, `example.com/org/net` and `.test`/`.example`/`.invalid`/`.localhost`
  addresses) and four-part version numbers, honours a `sensitive-ok` marker on a reviewed line
  and the values in `sensitive-allow.txt` (the file `cadenceux-skill-creator`'s validator
  reads), and applies the same filters with `--history`. On three published CadenceUX catalog
  skills its findings fell from 212 to 113 (BaseElements and bBox now clean); the MBS remainder
  is mostly real-looking addresses and emails in the vendor's examples, worth a look.
- **Start here** also runs `git ls-remote origin HEAD`: `gh auth status` can pass while git
  can't push, because `gh auth setup-git` writes `gh`'s full path into `~/.gitconfig` and the
  path goes stale when `gh` moves. New common-problems row for that error; step 1 says to
  re-run `gh auth setup-git` after moving or reinstalling `gh`.
- **How to work**: never overwrite files in the developer's own clone; update with `git pull`,
  and stop to ask about any uncommitted change first.
- The chat download block includes the two new scripts and the indicator file; both scripts
  find the file beside them as well as in `references/`.
- Relationship with `cadenceux-skill-creator`: both build release archives with
  `build_release.sh`, and share the placeholder rules and `sensitive-allow.txt`.

### Verified

- `check_known_attacks.sh` on a seeded wfx repo (payload commit and revert 40 s apart, hidden
  script, secrets dump, probe branch, compromised Action): every indicator found; on real
  CadenceUX clones and `--account CadenceUX` (12 repos, 32 s): clean. Tools check flagged three
  unpatched or end-of-life `git` copies and a stale credential helper on the test machine.
- `scan_skill.sh` on a seeded archive (path escape, symlink, zero-width character, hidden
  instruction, pre-approved shell, download-and-run, SSH key read, startup item, webhook,
  wfx install hook): all found; a real release archive and a catalog that quotes commands as
  documentation: clean. `--installed` across 36 installed skill and plugin folders: 40 s,
  clean after tuning out false positives found on that run.
- All three scanners report nothing on this skill's own folder (patterns written so they can't
  match themselves); `validate_skill.py` (cadenceux-skill-creator 2.4.2) clean.
- Evals on Haiku: 6/6 (`evals/results-2026-11-18.md`); the released 1.0.0 scored 1/4 on the
  four new cases.


## 1.0.0 — 2026-10-19

- First release, as `cadenceux-github`: a name with room for FileMaker script and code sharing
  later; it currently covers sharing a Claude skill.
- **Start here**: in Claude Code it inspects the folder (SKILL.md, Git, remote, tags, `gh` sign-in)
  and reports where the developer is before giving steps; in chat a bare `/cadenceux-github`
  gets one question (first publish, update, or fix a problem).
- **No GitHub account yet**: sign-up in the developer's own browser, choosing a username that
  appears in every install command, two-factor authentication with saved recovery codes, and a
  private noreply email for commits.
- **Reviewing published skills**: `scripts/review_published_skill.sh` reports, per repo, the
  version in all four places, commits since the last tag, uncommitted or unpushed work, the
  latest GitHub release and its unversioned archives, open issues and pull requests, and the
  version installed in Claude Code; each problem maps to a route. Content freshness is handed
  to `cadenceux-skill-creator`.
- Hand-offs with `cadenceux-skill-creator` declared both ways: it builds and tests, this skill
  publishes; updates start there and ship here.
- An eight-step first-publish workflow (sign-in, client-material scrub, repo
  shape, validation, private push, going public, release, install check), shipping updates,
  fixing a committed secret, and a common-problems table.
- `scripts/scan_for_client_material.sh` searches the files Git would commit, and optionally
  every past commit, for FileMaker addresses, credentials in script steps, keys, IP and email
  addresses and the developer's own client terms.
- `scripts/build_release.sh` builds the .zip and .skill archives from the release tag with
  `git archive`, checking the version in all four places, the folder name and that no plugin
  manifest is inside.
- Checked: `review_published_skill.sh` run on four published CadenceUX skill repos (one open
  issue found, three clean) and a seeded clone (versions disagree, unreleased and unpushed
  commits, uncommitted change, missing release archives all reported). Both other scripts tested against a seeded fixture repo (findings, clean pass, version
  mismatch, manifest leak); single-repo marketplace layout installed and validated with
  `claude plugin validate`; evals in `evals/results-2026-10-18.md`.

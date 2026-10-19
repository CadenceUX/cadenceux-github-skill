# Changelog

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

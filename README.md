# CadenceUX GitHub

A Claude skill that walks a FileMaker developer through publishing their own skill on GitHub,
so other developers can install it in Claude Code, the Claude app and Claude.ai.

It covers what a general Git guide doesn't:

- **Scrubbing client material** before the first commit: hostnames, `fmnet:` addresses,
  passwords in `Re-Login` steps, `.fmp12` files, SaXML and DDR exports. A bundled scanner
  checks the files and the whole history.
- **Shaping the repo** so one tree is the skill, a Claude Code plugin and its own marketplace.
- **Release archives that actually install**: one folder named after the skill, no plugin
  manifest, built from the tag. GitHub's own Download ZIP doesn't work as a skill upload.
- **Starting from nothing**: creating the GitHub account, with two-factor authentication and a
  private commit email.
- **Keeping published skills current**: a review script reports unreleased commits, version
  mismatches, missing release archives, open issues and out-of-date installed copies.
- **Updates and mistakes**: version bumps in all four places, never moving a tag, what to do
  when a password made it into history, and retiring a skill (archive first, delete only on
  purpose).
- **Known attacks on GitHub**: a script checks your Git versions, local clones (every commit,
  including ones an attacker reverted) and, with `gh`, every repo your account owns for the
  indicators of campaigns such as wfx and Gheist, which push secret-stealing workflow changes
  with stolen tokens. Indicators live in a data file so new campaigns are a quick update.
- **Is this skill safe?**: a second script checks a downloaded `.zip` or `.skill`, a skill
  folder, or every skill and plugin installed on your computer, for harmful scripts, hidden
  Unicode, injected instructions and pre-approved shell access, without installing or running
  anything.

In Claude Code it runs the `git` and `gh` commands, asking before each step that changes
something on GitHub. In chat, it gives the commands one at a time.

Try: *"I don't have a GitHub account yet"*, *"Help me put my FileMaker skill on GitHub"*, *"Are my published skills up to date?"*, *"Make my skill installable with claude
plugin install"*, *"Ship version 1.1.0 of my skill"*, *"Was my GitHub account hit by wfx?"*,
*"Is this skill zip safe to install?"*, *"Scan my installed skills"*.

## Install

**Claude Code (plugin):**

    claude plugin marketplace add https://github.com/CadenceUX/cadenceux-skills.git
    claude plugin install cadenceux-github@cadenceux

**Claude app on macOS:** download
[cadenceux-github.skill](https://github.com/CadenceUX/cadenceux-github-skill/releases/latest/download/cadenceux-github.skill)
and double-click it.

**Claude.ai, Claude Desktop or Cowork:** download
[cadenceux-github.zip](https://github.com/CadenceUX/cadenceux-github-skill/releases/latest/download/cadenceux-github.zip),
then upload it under Customize → Skills.

Use these release downloads, not GitHub's green **Code → Download ZIP** button: that archive
has the wrong folder layout and won't install as a skill.

## Requirements

Git (Git for Windows on Windows; commands run in Git Bash). The GitHub CLI (`gh`) is
recommended, and needed for account-wide attack checks. Claude Code is needed for
`claude plugin validate` and the install check. The skill scanner uses `unzip` or `python3`
and `perl`, which macOS, Linux and Git Bash include.

## Licence

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

Built and maintained by [Darrin Southern](https://www.linkedin.com/in/darrin-southern/) from [CadenceUX](https://cadenceux.com.au).

# Repo file templates

## Contents
- .claude-plugin/plugin.json
- .claude-plugin/marketplace.json
- .gitignore
- .gitattributes
- README install section
- CHANGELOG.md
- LICENSE

Replace `my-skill`, `owner`, `my-marketplace` and the names throughout. `my-skill` must equal the
`name` in SKILL.md's frontmatter.

## .claude-plugin/plugin.json

```json
{
  "name": "my-skill",
  "displayName": "My Skill",
  "version": "1.0.0",
  "description": "One or two sentences on what the skill does.",
  "author": { "name": "Your Name", "url": "https://example.com" },
  "homepage": "https://github.com/owner/my-skill",
  "repository": "https://github.com/owner/my-skill",
  "license": "CC-BY-4.0",
  "keywords": ["filemaker", "claris", "claude-skill"],
  "skills": ["./"]
}
```

`"skills": ["./"]` tells Claude Code the skill is the plugin root (SKILL.md at the top of the
repo). Keep `version` identical to SKILL.md's `metadata.version`.

## .claude-plugin/marketplace.json

```json
{
  "name": "my-marketplace",
  "description": "Claude skills for FileMaker developers from Your Name.",
  "owner": { "name": "Your Name", "url": "https://example.com" },
  "plugins": [
    {
      "name": "my-skill",
      "source": "./",
      "description": "One or two sentences on what the skill does.",
      "category": "development",
      "tags": ["filemaker", "claris"]
    }
  ]
}
```

`"source": "./"` points the marketplace at the plugin in the same repo. The marketplace `name` is
what users type after `@` (`claude plugin install my-skill@my-marketplace`); pick something
short and personal (`yourname` or your company), since one marketplace can later list several
skills from other repos:

```json
{ "name": "second-skill", "source": { "source": "url", "url": "https://github.com/owner/second-skill.git" }, "description": "…" }
```

## .gitignore

```gitignore
# macOS and Windows clutter
.DS_Store
Thumbs.db

# Release archives (built into dist/, attached to GitHub releases)
dist/
*.zip
*.skill

# Never commit FileMaker files, exports or secrets
*.fmp12
*.fmp12.*
*.fp7
*.xml.bak
saxml/
ddr/
exports/
.env
.env.*
!.env.example
*.pem
*.key
*.p12
```

Add the folder names this developer actually uses for test files and exports. If the skill
legitimately ships an XML file, ignore exports by folder, not with `*.xml`.

## .gitattributes

```gitattributes
* text=auto

.claude-plugin/ export-ignore
evals/ export-ignore
maintainer/ export-ignore
.gitignore export-ignore
.gitattributes export-ignore
```

`text=auto` stops Windows and macOS line endings fighting in diffs. The `export-ignore` lines
are read by `git archive` (and so by `scripts/build_release.sh`) and by GitHub's source zips:
they keep the plugin manifest, evals and Git files out of every archive. A `git clone`, which is
what the plugin install uses, still gets every file.

## README install section

```markdown
## Install

**Claude Code (plugin):**

    claude plugin marketplace add owner/my-skill
    claude plugin install my-skill@my-marketplace

**Claude app on macOS:** download
[my-skill.skill](https://github.com/owner/my-skill/releases/latest/download/my-skill.skill)
and double-click it.

**Claude.ai, Claude Desktop or Cowork:** download
[my-skill.zip](https://github.com/owner/my-skill/releases/latest/download/my-skill.zip), then
upload it under Customize → Skills.

Use these release downloads, not GitHub's green **Code → Download ZIP** button: that archive
has the wrong folder layout and won't install as a skill.

### Updating

    claude plugin marketplace update my-marketplace
    claude plugin update my-skill@my-marketplace

Zip and .skill users: download the latest release and install it again.
```

Above the install section, the README says what the skill does, when it triggers (two or three
example prompts), what it needs (FileMaker version, ADT, plug-ins), and its licence and author.

## CHANGELOG.md

```markdown
# Changelog

## 1.1.0 — 2026-11-02

- Added: …
- Fixed: …
- Checked: evals re-run on …; installed from the marketplace in a clean folder.

## 1.0.0 — 2026-10-18

- First public release.
```

Newest first. The heading's version must match `VERSION`; `build_release.sh` checks it. The
entry for a version, saved as `release-notes.md`, is the GitHub release notes.

## LICENSE

For CC BY 4.0, the file can be a short notice:

```text
This work is licensed under the Creative Commons Attribution 4.0 International License.
To view a copy of this license, visit https://creativecommons.org/licenses/by/4.0/
Copyright (c) 2026 Your Name
```

For MIT, use the standard text from choosealicense.com/licenses/mit/ (GitHub's "Add file →
Create new file → LICENSE" offers it as a template too). Match the `license` field in
`plugin.json` and the SKILL.md frontmatter.

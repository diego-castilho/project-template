# Contributing

> 🇧🇷 [Versão em português](CONTRIBUTING.pt-BR.md). Both versions change together, in the
> same PR, and CI checks that they have the same sections.

<!-- standards:begin core v0.3.1 -->

## Principles

They apply to every change, by any person or agent:

1. **Rules live in versioned documents.** An agent's local memory exists on one machine
   only; cloud conversations never read it. A new or corrected rule goes into the document,
   in the same PR that prompted it.
2. **Each rule has a single source.** Other places point to it. If two documents disagree,
   the source wins and the other is fixed in the same PR.
3. **Each rule says why it exists.** The reason is what stops someone from "simplifying" it
   later.
4. **Each rule says how it is enforced:** `Doc` (depends on the reader), `Skill` (an
   executable runbook), `Auto` (CI or GitHub do it), `Confirm` (a hook asks for
   confirmation) or `Blocked` (a hook always refuses).
5. **Pending work becomes an issue.** Never a loose item in a `.md`.
6. **An authorization covers that action, at that moment.** It does not extend to the next.

## Where each rule lives

| Subject | Source | Enforcement |
|---|---|---|
| Process: branch, commit, PR, merge, release, hotfix, issues | this file | Doc + Auto |
| What is agent-specific: session start, stops, worktrees | [CLAUDE.md](CLAUDE.md) | Doc + Confirm |
| Project configuration: scopes, version, gates, production | [.standards.json](.standards.json) | Auto |
| Executable release, hotfix and cross-repo requests | skills [`/release`](.claude/skills/release/SKILL.md), [`/hotfix`](.claude/skills/hotfix/SKILL.md) and [`/xrepo`](.claude/skills/xrepo/SKILL.md), installed with `gh skill` at the standard's version | Skill |
| Agent guards | [.claude/settings.json](.claude/settings.json) and [.claude/hooks/](.claude/hooks/) | Confirm + Blocked |
| Commit, branch and PR checks, Actions lockfile | the `dev-standards` `standards` workflow | Auto |
| Branch protection on GitHub | `.standards/rulesets.sh` | Blocked |
| All of this as a visual map, with diagrams (not a source: it points here) | [docs/REGRAS.md](docs/REGRAS.md) (PT) | — |

A machine's environment (where `gh` lives, 1Password, node in a container) is **not** a
project rule: it goes in that machine's `~/.claude/CLAUDE.md`, versioned in the dotfiles.

## Branch flow (gitflow)

```
feat/* fix/* docs/* chore/* …  ──merge commit──▶  develop  ──squash (release)──▶  main
                                                     ▲                             │
                                                     └────── merged back ──────────┤
hotfix/X.Y.Z  ◀──── branches off the production tag ───────────────────────────────┘
hotfix/X.Y.Z  ──squash (hotfix)──▶  main  ──merged back──▶  develop
```

- **`main`** is what is published. It only changes through the squash of a release or
  hotfix PR. It **never** takes a direct push (Blocked).
- **`develop`** is the working line. It takes short branches through merge commits, which
  keep the history and the branch name in the subject. It **never** takes a force-push.
- `develop` showing "N commits ahead" of `main` is expected, because only `main` is
  squashed. Do not "align" them.

### Branch names

| Prefix | Use | Base | Target |
|---|---|---|---|
| `feat/` | feature | `develop` | `develop` |
| `fix/` | fix that can wait for the next release | `develop` | `develop` |
| `docs/` | documentation only | `develop` | `develop` |
| `refactor/`, `perf/`, `test/` | internal change with no user-facing effect | `develop` | `develop` |
| `chore/`, `ci/`, `build/` | maintenance, CI, build, dependencies | `develop` | `develop` |
| `chore/bump-X.Y.Z` | release version PR | `develop` | `develop` |
| `hotfix/X.Y.Z` | urgent production fix | tag `vX.Y.Z-1` | `main` |

Format: `<prefix><issue-number>-<kebab-case-slug>`, with the number when there is an issue:
`fix/236-dedup-entries`, `feat/oauth-login`. Lowercase, no accents. CI rejects branches
outside this format (Auto). The only exception is `claude/…`, the name Claude Code in the
cloud gives a branch by itself: it passes, and the PR title still follows the commit format.

**The branch is deleted on merge** (GitHub does it). The merge commit keeps the name and
the PR keeps the diff, with "Restore branch". Before deleting a branch outside that flow,
check that `git branch -r --no-merged origin/develop` does not list it.

### Stacked PRs

When a change is too big for one PR, split it into a stack of PRs that build on each other
and manage it with **`gh stack`** (the [github/gh-stack](https://github.com/github/gh-stack)
extension), which GitHub knows as a stack:

1. `gh stack init` from `develop`, then `gh stack add <branch>` for each layer; each branch
   follows the branch-name rules.
2. `gh stack submit` pushes every branch and opens the PRs. Each PR's rules and CI are
   evaluated against `develop`, the stack's trunk.
3. Review and merge **from the bottom up** with `gh stack merge --merge`. The extension
   retargets the PRs above and rebases them, and the rebased commits are signed.
4. `gh stack sync` brings the local stack up to date after any change on GitHub.

Never change the base of a PR in a stack by hand, and never delete a stack branch yourself:
both leave GitHub's stack out of step with the branches.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/), **in English**, imperative mood,
no trailing period (Auto). The subject aims at **72 characters**, where `git log --oneline` and
GitHub start cutting: above that CI warns, and above **100** it rejects.

```
feat(auth): add OAuth login with GitHub
fix(import): keep the original currency when the export omits it
docs(api): describe the pagination headers
chore(release): 1.4.0
```

| Type | Use | CHANGELOG section |
|---|---|---|
| `feat` | new feature | Added / Adicionado |
| `fix` | fix | Fixed / Corrigido |
| `perf` | performance | Changed / Alterado |
| `refactor` | internal change with no visible effect | — |
| `style` | formatting, no behavior change | — |
| `docs` | documentation | Documentation / Documentação |
| `test` | tests | — |
| `build`, `ci`, `chore` | build, CI, maintenance | — (or Changed, if users notice) |
| `revert` | reverts a commit | the section of what was reverted |

**A scope is required in `feat`, `fix`, `perf` and `refactor`**, the commits that become
CHANGELOG lines and need to say where they change things, and optional in the others
(`docs: …`, `ci: …`). When present, the scope must be in `commitScopes` in
[.standards.json](.standards.json). A breaking change takes `!` (`feat(api)!: …`) and a
`BREAKING CHANGE:` footer. The subjects `release: vX.Y.Z` and `hotfix: vX.Y.Z` belong to the
squash into `main` and reach `develop` through the merge back.

**The body explains the problem**, not just the change: open with the symptom, describe the
cause and only then what changed. A commit with a generic subject and no body makes "why
was this done this way" impossible to answer months later.

**Commit order in a branch: spec → implementation → changelog.** First the documentation
that describes the behavior (contract, data model, ADR), then the code and tests, and last
the CHANGELOG entry.

**Everything is signed:** commits, merges and tags (SSH). GitHub shows *Verified*, and
`main` and `develop` reject unsigned commits (Blocked, through `rulesets.sh`, which needs
GitHub Pro on a private repository). To check:
`git cat-file -p <sha> | grep -cE 'BEGIN (SSH|PGP) SIGNATURE'`. Merges and squashes made by
GitHub are signed by it with PGP, not by your SSH key, and count too.

## Pull requests

- **Base `develop`**, except release and hotfix PRs, whose base is `main` (Auto).
- **Title** in commit format (`feat(auth): add OAuth login`). Release PR:
  `release: vX.Y.Z`. Hotfix PR: `hotfix: vX.Y.Z` (Auto).
- **Body** from the [template](.github/pull_request_template.md): problem, what changes,
  verification and `Refs #N`.
- Use `Refs #N`, **not** `Fixes #N`: closing an issue takes the resolution comment, which
  auto-closing skips (see [Issues](#issues-and-labels)).
- **Before opening:** the `verify` command from `.standards.json` passes locally. It is what
  CI runs; finding out through the workflow is slower. When `verify` only runs on a specific
  machine (Xcode on a Mac, for instance), `verifyRunsIn: "local"` makes CI skip it and the
  result goes in the PR's Verification section.

Checklist for every PR into `develop`:

- [ ] A test covering the change. For a fix, a test that **fails without it**, naming the
      regression in the test title.
- [ ] Documentation updated in the same PR.
- [ ] A `CHANGELOG.md` entry under `[Unreleased]`, in PT and EN, describing the impact rather
      than repeating the commit message.
- [ ] No [sensitive data](#sensitive-data) in the diff.
- [ ] A hard-to-reverse decision has an ADR.

## Merge

**Check the base before every merge:** `gh pr view N --json baseRefName`. The hook refuses
to merge a `main`-based PR that is neither a release nor a hotfix (Blocked).

| PR | Method | Command |
|---|---|---|
| short branch → `develop` | merge commit | `gh pr merge N --merge --delete-branch` |
| release `develop` → `main` | squash | `gh pr merge N --squash --subject "release: vX.Y.Z" --body "<one line>"` |
| hotfix → `main` | squash | `gh pr merge N --squash --subject "hotfix: vX.Y.Z" --body "<one line>"` |

Without `--subject`, `main` gets "title (#N)". Into `develop` there is no `--subject`: the
repository is set (`rulesets.sh`) so that the merge commit takes the PR title and body, which
reads better in `git log` than "Merge pull request #N from …".

The **default branch on GitHub is `develop`** (`rulesets.sh` sets it): new PRs, Dependabot's
included, start with the right base. A PR that arrives based on `main` without being a
release or hotfix is retargeted with `gh pr edit N --base develop` before merging.

## Release

Executable runbook: the [`/release`](.claude/skills/release/SKILL.md) skill. Steps marked
**STOP** wait for the maintainer's explicit confirmation.

1. **Everything for the version is in `develop`**, with green CI, and the CHANGELOG's
   `[Unreleased]` describes everything that ships (`git log origin/main..origin/develop`).
2. **Pick the version** by SemVer (below). **STOP:** version and summary for confirmation.
3. **`chore/bump-X.Y.Z` PR** into `develop`, with one `chore(release): X.Y.Z` commit:
   - the files in `release.versionFiles`, edited by hand;
   - the commands in `release.preBumpCommands`;
   - `[Unreleased]` closed as `[X.Y.Z] - YYYY-MM-DD`, with an empty `[Unreleased]` above.
4. **Project gates** (`release.gates`): each one is a **STOP**. Example: validating an app on
   a device against the development environment.
5. **`develop` → `main` PR**, titled `release: vX.Y.Z`, body `## 🇧🇷 Português`,
   `## 🇺🇸 English` (the version's sections) and `## Verificação` at the end.
   **STOP** before the squash.
6. **Annotated, signed tag** on the squash commit:
   `git tag -s vX.Y.Z -m vX.Y.Z origin/main && git push origin vX.Y.Z` (Confirm).
7. **GitHub Release:**
   `gh release create vX.Y.Z --verify-tag --latest --title "vX.Y.Z — <PT phrase> / <English phrase>" --notes-file <PR body without Verificação>` (Confirm).
8. **`main` back into `develop`**, as a signed merge:
   `git merge --no-ff -S origin/main -m "Merge branch 'main' into develop"` and push.
   Without it, `develop` and `main` drift apart with every release.
9. **Production**, if the project has one (`production.deployDoc`). **STOP:** only with
   explicit authorization.
10. **Notify sibling repos**, if `xrepo.enabled`: a sync issue in each one that consumes
    something from this one.

If the release ships and production cannot follow, open an issue for the deploy and do not
mark the version as deployed.

## Hotfix

For a defect **in production** that cannot wait, when `develop` already holds work that
cannot ship yet. If `develop` can ship as a whole, cut a normal patch release instead.
Executable runbook: the [`/hotfix`](.claude/skills/hotfix/SKILL.md) skill.

1. **Issue** of type `Bug` with Priority `Urgent`. **STOP:** confirm it is a hotfix, not a
   release.
2. **`hotfix/X.Y.Z` branch** from the **production tag**, not from `develop`:
   `git switch -c hotfix/1.4.1 v1.4.0`. That way nothing in progress comes along.
3. In the branch, in this order: the test that fails without the fix, the fix, the version
   bump (`chore(release): X.Y.Z`) and the CHANGELOG entry already as
   `[X.Y.Z] - YYYY-MM-DD`.
4. **`hotfix/X.Y.Z` → `main` PR**, titled `hotfix: vX.Y.Z`, bilingual body with
   `## Verificação`. **STOP** before the squash.
5. **Tag, GitHub Release and production**, as in release steps 6, 7 and 9.
6. **`main` back into `develop`**, as in release step 8. In `develop`'s CHANGELOG, the
   `[X.Y.Z]` section goes **below** `[Unreleased]`, which keeps what was already there. It
   is the most forgotten step: without it, the next release wipes out the fix.

A hotfix skips the long release gates (`release.gates`) only if the maintainer says so; it
never skips the tag, the production confirmation or the merge back.

## Versioning and CHANGELOG

[SemVer](https://semver.org/): fix → patch; backward-compatible feature → minor; breaking a
contract or a data format → major, with the migration path described in the CHANGELOG.
Before 1.0.0, a breaking change bumps the minor.

`CHANGELOG.md` follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and is
**bilingual**: each version has `### 🇧🇷 Português` and `### 🇺🇸 English`, with the same
sections (`Adicionado/Added`, `Alterado/Changed`, `Corrigido/Fixed`, `Removido/Removed`,
`Segurança/Security`, `Documentação/Documentation`). An entry describes the effect for
users, does not repeat the commit message, and cites the issue (`(#123)`).

## Issues and labels

**All pending work becomes an issue**, in the repository where the work happens, never an
item in a `BACKLOG.md`, a plan or a TODO list. A document may group pending work (a fix plan,
a roadmap), but each open item points to its issue. Use the
[templates](.github/ISSUE_TEMPLATE/): bug, feature, task, docs, question and, across
repositories, xrepo request. Each form sets the issue type. Blank issues are disabled. A
repository that does not follow the standard gets the same forms, without the xrepo one,
from the account's public `.github` repository.

Type and priority are **native GitHub features**, defined once per account or organization
by `.standards/issue-types.sh setup` from `.standards/issue-types.json`:

| What | Values | Rule |
|---|---|---|
| Issue type | `Bug`, `Feature`, `Task`, `Docs`, `Question` | exactly one |
| Priority field | `Urgent` (blocking or user at risk), `High` (broken, no risk), `Medium` (worthwhile improvement), `Low` (can wait) | exactly one, set at triage |

`gh issue create --type <Type>` sets the type; `gh` has no flag for issue fields, so the
priority goes through `.standards/issue-types.sh priority <owner/repo> <n> <value>`. Search
with `type:Bug` and `field.priority:urgent`.

Labels cover what GitHub has no native feature for. They are the same in every project,
created by `.standards/labels.sh`:

| Group | Labels | Rule |
|---|---|---|
| Contract | `contract` | the change touches a contract another repository consumes |
| Status | `status:needs-info`, `status:needs-decision`, `status:blocked` | zero or more |
| Verification | `needs-verification` | resolved, waiting for the requester |
| Cross-repo | `xrepo`, `from:<repo>`, `parity` | only with `xrepo.enabled` |

An issue's lifecycle:

1. Opened with a type; the priority is set at triage.
2. A branch with the number (`fix/123-slug`) and a PR with `Refs #123`.
3. After the merge, a resolution comment and the close:

   ```markdown
   ## Resolução

   - PR: #<n> (merged into `develop`, commit `<short sha>`)
   - What changed: <1 to 3 lines>
   - Action needed in another repo: none | <what>
   - Ships in: `[Unreleased]` | `vX.Y.Z`
   ```

4. If it will not be done: comment why and close with `--reason "not planned"`.

**Across repositories** (`xrepo.enabled`), the issue lives in the repo where the work
happens. The executable runbook, with the commands, is the [`/xrepo`](.claude/skills/xrepo/SKILL.md)
skill:

- the requester opens the issue in the other repo with a type and the `xrepo` and
  `from:<this-repo>` labels, passed explicitly to `gh issue create` (template settings only
  apply on the web), then sets its priority;
- whoever handles it comments the resolution, adds `needs-verification` and closes;
- the requester checks it against the acceptance criteria and removes `needs-verification`,
  or reopens saying what is missing. **Only the requester removes `needs-verification`; only
  the handler closes.**
- Permanent knowledge (contracts, decisions) lives in a versioned document; the issue points
  to it and does not replace it. Repos never write files into each other.

## Documentation, ADRs and audits

- **The code is the source of truth.** A document citing a number or constant points to the
  file instead of repeating the value.
- **Living docs** (architecture, API, operations) cite function names, not `file:line`,
  which ages with every change.
- **ADRs** in [docs/adr/](docs/adr/) for decisions that are hard to reverse, that a
  reasonable person would make differently, or that the code alone does not explain. An ADR
  is not edited when the decision changes: write the next one and mark the old one as
  superseded.
- **An audit record** is a snapshot of the code on a date: it lives in the `docs.auditDir`
  folder of `.standards.json` (default `docs/audits/`), as `YYYY-MM-DD-<subject>.md` or in a
  subfolder when it has several phases, names in its header the commit it describes, points
  code links to that commit, uses an ID prefix not yet in the repo
  (`git grep -wE '<PREFIX>[0-9]{2}'` empty), and each open finding has an issue.

## Dependencies

- **Actions are pinned in a lockfile.** `gh actions-lock` (the
  [github/gh-actions-lock](https://github.com/github/gh-actions-lock) extension) writes
  `.github/workflows/actions.lock`, with every action, transitive ones included, pinned to a
  commit; the runner refuses a pin that does not match. Run it after adding or changing a
  `uses:` and commit the lockfile with the workflow. The `standards` check verifies it on every
  PR.
- **Dependabot opens the updates** (`.github/dependabot.yml`, seeded once and then the
  project's): one PR per ecosystem and week, minor and patch grouped, based on `develop`,
  titled `chore(deps): …`. Security updates arrive on their own, as soon as an advisory is out.
  Add a block for each ecosystem the project uses.
- A dependency update is merged like any other PR: CI green, merge commit into `develop`.
- **The checks run as an action.** A project's `standards.yml` calls
  `diego-castilho/dev-standards/check@vX.Y.Z`, so the version in the tag is the version
  enforced, and the sync only changes that tag. If the repository restricts which actions may
  run, allow `diego-castilho/dev-standards/check@*`.

## Sensitive data

Never in a commit, doc, issue, PR or log, **even in a private repository**:

- tokens, passwords, keys, URLs with credentials, `.env`;
- real personal or customer data (the project's list is `sensitive` in `.standards.json`);
- real IP addresses, internal host names or topology that leads to a service. In documents,
  use documentation addresses (`192.0.2.x`, RFC 5737) or the service name. CI rejects private
  network addresses in Markdown (Auto, `check.sh docs`);
- unsanitized fixtures: describe the format; the sanitized fixture comes in through the PR.

Database dumps stay outside the repository, with `600` permissions, and are deleted once they
no longer serve as a rollback.

## Languages

| What | Language |
|---|---|
| Commits, branch names, labels, code and code comments | English |
| `CHANGELOG.md`, release and hotfix PRs, GitHub Releases | PT and EN |
| `README`, `CONTRIBUTING`, `SECURITY` | EN in `.md`, PT in `.pt-BR.md`, with the same sections (Auto) |
| `CLAUDE.md`, `docs/`, ADRs, issues | Portuguese |

<!-- standards:end -->

## Project-specific

<!-- What applies only here: domain rules, i18n, contracts, environments. This part belongs
     to the project; the standards sync never touches it. -->

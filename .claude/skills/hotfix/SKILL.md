---
description: Ship an urgent production fix under dev-standards — hotfix branch from the production tag, failing test, fix, version bump, hotfix PR to main (squash), signed tag, GitHub Release, production and the merge back into develop. Use when a defect in production cannot wait for the next release and develop holds work that cannot ship yet. For a normal release, use the release skill.
metadata:
    github-path: .claude/skills/hotfix
    github-pinned: v0.3.1
    github-ref: refs/tags/v0.3.1
    github-repo: https://github.com/diego-castilho/dev-standards
    github-tree-sha: 511b08f4709d7ced44546f1ad61cd935eb9e27d0
name: hotfix
---
# Hotfix

Executa o [CONTRIBUTING.pt-BR.md, "Hotfix"](../../../CONTRIBUTING.pt-BR.md#hotfix). Se este
roteiro e o CONTRIBUTING divergirem, **o CONTRIBUTING vale**.

Leia antes o [CLAUDE.md](../../../CLAUDE.md) ("Paradas obrigatórias") e o
[.standards.json](../../../.standards.json). Trabalhe numa worktree. **PARE** quer dizer:
mostre o estado ao usuário e espere a resposta dele.

## 0. É hotfix mesmo?

```bash
git fetch -q origin --tags
prod="$(git describe --tags --abbrev=0 origin/main)"; echo "$prod"
git log --oneline origin/main..origin/develop | head -20   # o que está na develop e não saiu
```

- Se a `develop` pode sair inteira, isto é uma release patch: use a skill `release`.
- Precisa existir uma issue do tipo `Bug` com Priority `Urgent`. Se não existir, abra
  (`gh issue create --type Bug` e `.standards/issue-types.sh priority <repo> <n> Urgent`).
- **PARE:** mostre a versão em produção, a versão do hotfix (patch + 1) e por que não dá
  para esperar a release. Siga com o "ok".

## 1. Branch a partir da tag em produção

```bash
git worktree add <scratchpad>/hotfix -b hotfix/X.Y.Z "$prod"
```

Nunca a partir da `develop`: o que está lá não pode ir junto.

## 2. Commits, nesta ordem

1. `test(<escopo>): …` — o teste que **falha sem a correção**, com a regressão no título.
2. `fix(<escopo>): …` — a correção, com o corpo explicando sintoma, causa e mudança.
3. `chore(release): X.Y.Z` — os arquivos de `release.versionFiles`, os
   `release.preBumpCommands`, e o CHANGELOG com a seção `## [X.Y.Z] - AAAA-MM-DD`, PT e EN,
   logo abaixo do `[Unreleased]` (que fica como estava na tag).

Rode o `verify`. Tudo assinado.

## 3. PR para a `main`

```bash
git push -u origin hotfix/X.Y.Z
gh pr create --base main --head hotfix/X.Y.Z --title "hotfix: vX.Y.Z" --body-file /tmp/hotfix-body.md
```

Corpo como o da release (🇧🇷 / 🇺🇸 com `### Corrigido` / `### Fixed`, e `## Verificação`,
citando a issue). Gates de `release.gates`: rode os que o usuário pedir; pergunte.
**PARE** antes do squash:

```bash
gh pr merge N --squash --subject "hotfix: vX.Y.Z" --body "<uma linha>"
```

## 4. Tag, GitHub Release e produção

Como na skill `release`, passos 4 e 6: tag `vX.Y.Z` assinada no commit do squash, release
com `--latest`, e produção só com **PARE**.

## 5. `main` de volta para `develop` (não pule)

```bash
git switch develop && git pull --ff-only
git merge --no-ff -S origin/main -m "Merge branch 'main' into develop"
```

Conflito esperado no CHANGELOG: o resultado tem o `[Unreleased]` da `develop` intacto no
topo e a seção `[X.Y.Z]` do hotfix logo abaixo, antes da versão anterior. Nos arquivos de
versão, fica a versão do hotfix. Rode o `verify` e faça o push.

## 6. Fechar a issue

Comentário de resolução (CONTRIBUTING, "Issues e labels") com o PR, a tag e "Sai em:
`vX.Y.Z`", e feche. Remova a worktree.

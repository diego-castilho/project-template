---
description: Cut a release end to end under dev-standards — version choice, bump PR, project gates, release PR to main (squash), signed tag, GitHub Release, main back into develop, production and sibling-repo sync. Use whenever someone asks to release, publish, version, tag or ship a new version, or to deploy a version to production. For an urgent production fix that cannot wait for develop, use the hotfix skill instead.
metadata:
    github-path: .claude/skills/release
    github-pinned: v0.3.1
    github-ref: refs/tags/v0.3.1
    github-repo: https://github.com/diego-castilho/dev-standards
    github-tree-sha: bb3b94fc6221a23833a382773e3d3104955b5335
name: release
---
# Release

Executa o [CONTRIBUTING.pt-BR.md, "Release"](../../../CONTRIBUTING.pt-BR.md#release). Se
este roteiro e o CONTRIBUTING divergirem, **o CONTRIBUTING vale**: avise o usuário e corrija
este arquivo no mesmo PR.

Antes de começar, leia o [CLAUDE.md](../../../CLAUDE.md) ("Paradas obrigatórias" e
"Conversas em paralelo") e o [.standards.json](../../../.standards.json): `project.repo`,
`release.versionFiles`, `release.preBumpCommands`, `release.gates`, `production` e `xrepo`.
Trabalhe numa worktree se o checkout principal não estiver limpo em `develop`.

Mantenha uma lista com os passos e marque cada um ao concluir. **PARE** quer dizer: mostre
ao usuário o estado e espere a resposta dele. Não siga por conta própria, mesmo que o pedido
original pareça cobrir.

## 0. Pré-checagem

```bash
git fetch -q origin --tags
git log --oneline origin/main..origin/develop | head -40   # o que vai sair
gh pr list --state open --json number,title,baseRefName     # algo pendente que deveria entrar?
git describe --tags --abbrev=0 origin/main 2>/dev/null       # versão atual (vazio na primeira)
sed -n '/^## \[Unreleased\]/,/^## \[/p' CHANGELOG.md        # o que o CHANGELOG diz
```

- O `[Unreleased]` precisa descrever **tudo** o que está em `origin/main..origin/develop`, em
  PT e EN. Se faltar entrada, ela entra por um PR antes do bump.
- Versão pelo SemVer: correção → patch; funcionalidade retrocompatível → minor; quebra →
  major (antes da 1.0.0, quebra sobe o minor).
- **PARE:** mostre a versão proposta e o resumo do que sai.

## 1. PR de bump `chore/bump-X.Y.Z`

1. Branch `chore/bump-X.Y.Z` a partir de `origin/develop`.
2. Edite **à mão** cada arquivo de `release.versionFiles` (inclusive `standardsVersion`, se
   o projeto for o próprio dev-standards). Confira o diff: só as linhas de versão mudam.
3. Rode cada comando de `release.preBumpCommands`.
4. CHANGELOG: `## [Unreleased]` vazio no topo e, abaixo, as entradas sob
   `## [X.Y.Z] - AAAA-MM-DD`.
5. Um commit, assinado: `chore(release): X.Y.Z`.
6. `verify`, push, PR para `develop` com título `chore(release): X.Y.Z`, CI verde, merge
   commit com `--delete-branch`.

## 2. Gates do projeto

Para cada item de `release.gates`: execute o que der para executar (deploy no ambiente de
desenvolvimento, migrações) e **PARE** no que depende do usuário (validar num aparelho, por
exemplo). Sem a confirmação de cada gate, não há passo 3. Sem gates, siga.

## 3. PR `develop` → `main`

```bash
gh pr create --base main --head develop --title "release: vX.Y.Z" --body-file /tmp/release-body.md
```

Corpo, fora do repositório:

```markdown
## 🇧🇷 Português

### Adicionado
- …

## 🇺🇸 English

### Added
- …

## Verificação

- CI verde no PR de bump e neste
- `verify` ok
- Gates: <cada um e o resultado>
```

As seções saem do CHANGELOG da versão, sem reescrever. **PARE:** mostre o PR e espere o
"ok" para o squash.

```bash
gh pr merge N --squash --subject "release: vX.Y.Z" --body "<uma linha>"
```

## 4. Tag e GitHub Release

```bash
git fetch -q origin
git tag -s vX.Y.Z -m vX.Y.Z origin/main
git push origin vX.Y.Z
gh release create vX.Y.Z --verify-tag --latest \
  --title "vX.Y.Z — <frase PT> / <English phrase>" \
  --notes-file /tmp/release-notes.md   # o corpo do PR sem "Verificação"
```

Os hooks pedem confirmação em cada um: é esperado.

## 5. `main` de volta para `develop`

```bash
git switch develop && git pull --ff-only
git merge --no-ff -S origin/main -m "Merge branch 'main' into develop"
git push origin develop
```

Conflito só no CHANGELOG ou nos arquivos de versão: fique com o conteúdo da `develop` e a
versão nova.

## 6. Produção

Só se `production.deployDoc` existir. Siga o documento. **PARE** antes de qualquer comando
que altere produção. Se a produção não puder ir agora, abra uma issue para o deploy.

## 7. Repos irmãos

Só com `xrepo.enabled`: para cada repo de `xrepo.repos` que consome algo deste, abra uma
issue de sync (template xrepo, tipo `Task`, labels `xrepo,from:<self>,contract`, Priority `High`) com a
tag e o que mudou. **PARE** antes de publicar: o hook pede confirmação.

## Fim

Resumo ao usuário: versão, links do PR, da tag e da release, estado da produção e das
issues de sync.

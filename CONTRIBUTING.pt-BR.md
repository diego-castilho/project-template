# Contribuindo

> 🇺🇸 [English version](CONTRIBUTING.md). As duas versões mudam juntas, no mesmo PR,
> e o CI confere que têm as mesmas seções.

<!-- standards:begin core v0.3.1 -->

## Princípios

Valem para qualquer mudança, de qualquer pessoa ou agente:

1. **Regra vive em documento versionado.** A memória local de um agente só existe numa
   máquina; conversas na nuvem não a leem. Regra nova ou corrigida entra no documento, no
   mesmo PR que a motivou.
2. **Cada regra tem uma fonte só.** Os outros lugares apontam para ela. Se dois documentos
   divergirem, vale a fonte, e o outro é corrigido no mesmo PR.
3. **Cada regra diz por que existe.** O motivo é o que impede alguém de "simplificar" a
   regra depois.
4. **Cada regra diz o quanto é garantida:** `Doc` (depende de quem lê), `Skill` (roteiro
   executável), `Auto` (CI ou GitHub fazem sozinhos), `Confirma` (um hook pede confirmação)
   ou `Bloqueado` (um hook recusa sempre).
5. **Pendência vira issue.** Nunca item solto num `.md`.
6. **Autorização vale para aquela ação, naquele momento.** Não se generaliza para a próxima.

## Onde vive cada regra

| Assunto | Fonte | Garantia |
|---|---|---|
| Processo: branch, commit, PR, merge, release, hotfix, issues | este arquivo | Doc + Auto |
| O que é específico de agente: início de sessão, paradas, worktrees | [CLAUDE.md](CLAUDE.md) | Doc + Confirma |
| Configuração do projeto: escopos, versão, gates, produção | [.standards.json](.standards.json) | Auto |
| Release, hotfix e pedidos entre repos, executáveis | skills [`/release`](.claude/skills/release/SKILL.md), [`/hotfix`](.claude/skills/hotfix/SKILL.md) e [`/xrepo`](.claude/skills/xrepo/SKILL.md), instaladas com `gh skill` na versão do padrão | Skill |
| Travas do agente | [.claude/settings.json](.claude/settings.json) e [.claude/hooks/](.claude/hooks/) | Confirma + Bloqueado |
| Checagem de commits, branches e PRs | workflow `standards` do `dev-standards` | Auto |
| Proteção das branches no GitHub | `.standards/rulesets.sh` | Bloqueado |
| Tudo isso num mapa visual, com diagramas (não é fonte: aponta para cá) | [docs/REGRAS.md](docs/REGRAS.md) | — |

O ambiente de uma máquina (caminho do `gh`, 1Password, node em container) **não** é regra
do projeto: vai no `~/.claude/CLAUDE.md` daquela máquina, versionado nos dotfiles.

## Fluxo de branches (gitflow)

```
feat/* fix/* docs/* chore/* …  ──merge commit──▶  develop  ──squash (release)──▶  main
                                                     ▲                             │
                                                     └──── merge de volta ─────────┤
hotfix/X.Y.Z  ◀──── sai da tag em produção ────────────────────────────────────────┘
hotfix/X.Y.Z  ──squash (hotfix)──▶  main  ──merge de volta──▶  develop
```

- **`main`** é o que está publicado. Só muda pelo squash de um PR de release ou de hotfix.
  **Nunca** recebe push direto (Bloqueado).
- **`develop`** é a linha de trabalho. Recebe as branches curtas por merge commit, que
  guarda o histórico e o nome da branch no assunto. **Nunca** recebe force-push.
- `develop` aparecer "N commits à frente" de `main` é esperado, porque só a `main` é
  compactada. Não "alinhe" as duas.

### Nomes de branch

| Prefixo | Uso | Base | Destino |
|---|---|---|---|
| `feat/` | funcionalidade | `develop` | `develop` |
| `fix/` | correção que pode esperar a próxima release | `develop` | `develop` |
| `docs/` | só documentação | `develop` | `develop` |
| `refactor/`, `perf/`, `test/` | mudança interna sem efeito para o usuário | `develop` | `develop` |
| `chore/`, `ci/`, `build/` | manutenção, CI, build, dependências | `develop` | `develop` |
| `chore/bump-X.Y.Z` | PR de versão da release | `develop` | `develop` |
| `hotfix/X.Y.Z` | correção urgente em produção | tag `vX.Y.Z-1` | `main` |

Formato: `<prefixo><número-da-issue>-<slug-em-kebab-case>`, com o número quando houver
issue: `fix/236-dedup-entries`, `feat/oauth-login`. Letras minúsculas, sem acento.
O CI recusa branch fora deste formato (Auto). A única exceção é `claude/…`, o nome que o
Claude Code na nuvem dá sozinho à branch: ela passa, e o título do PR continua no formato de
commit.

**A branch é apagada no merge** (o GitHub faz sozinho). O merge commit guarda o nome e o PR
guarda o diff, com "Restore branch". Antes de apagar uma branch fora desse fluxo, confira
que `git branch -r --no-merged origin/develop` não a lista.

### PRs empilhados

Quando uma mudança é grande demais para um PR, divida-a numa pilha de PRs que se apoiam uns
nos outros e cuide dela com o **`gh stack`** (extensão
[github/gh-stack](https://github.com/github/gh-stack)), que o GitHub reconhece como pilha:

1. `gh stack init` a partir da `develop` e `gh stack add <branch>` para cada camada; cada
   branch segue as regras de nome.
2. `gh stack submit` envia todas as branches e abre os PRs. As regras e o CI de cada PR são
   avaliados contra a `develop`, o tronco da pilha.
3. Revise e faça o merge **de baixo para cima** com `gh stack merge --merge`. A extensão
   aponta os PRs de cima para a nova base e faz o rebase, e os commits rebaseados saem
   assinados.
4. `gh stack sync` atualiza a pilha local depois de qualquer mudança no GitHub.

Nunca mude à mão a base de um PR da pilha nem apague você mesmo uma branch dela: as duas
coisas deixam a pilha do GitHub fora de sincronia com as branches.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/), **em inglês**, no imperativo e
sem ponto final (Auto). O assunto mira **72 caracteres**, que é onde `git log --oneline` e o
GitHub começam a cortar: acima disso o CI avisa, e acima de **100** ele recusa.

```
feat(auth): add OAuth login with GitHub
fix(import): keep the original currency when the export omits it
docs(api): describe the pagination headers
chore(release): 1.4.0
```

| Tipo | Uso | Seção do CHANGELOG |
|---|---|---|
| `feat` | funcionalidade nova | Adicionado / Added |
| `fix` | correção | Corrigido / Fixed |
| `perf` | desempenho | Alterado / Changed |
| `refactor` | mudança interna sem efeito visível | — |
| `style` | formatação, sem mudança de comportamento | — |
| `docs` | documentação | Documentação / Documentation |
| `test` | testes | — |
| `build`, `ci`, `chore` | build, CI, manutenção | — (ou Alterado, se o usuário sentir) |
| `revert` | reverte um commit | a seção do que foi revertido |

**Escopo é obrigatório em `feat`, `fix`, `perf` e `refactor`**, os commits que viram linha do
CHANGELOG e precisam dizer onde mexem, e opcional nos demais (`docs: …`, `ci: …`). Quando
aparece, o escopo tem que estar em `commitScopes` no [.standards.json](.standards.json).
Mudança que quebra compatibilidade leva `!` (`feat(api)!: …`) e um rodapé `BREAKING CHANGE:`.
Os assuntos `release: vX.Y.Z` e `hotfix: vX.Y.Z` são os do squash na `main` e chegam à
`develop` pelo merge de volta.

**O corpo explica o problema**, não só a mudança: abra pelo sintoma, descreva a causa e só
então o que mudou. Commit com assunto genérico e sem corpo torna impossível responder "por
que isto foi feito assim" meses depois.

**Ordem dos commits numa branch: spec → implementação → changelog.** Primeiro a
documentação que descreve o comportamento (contrato, modelo de dados, ADR), depois o código
e os testes, e por último a entrada no CHANGELOG.

**Tudo assinado:** commits, merges e tags (SSH). O GitHub mostra *Verified*, e a `main` e a
`develop` recusam commit sem assinatura (Bloqueado, por `rulesets.sh`, que exige GitHub Pro
em repositório privado). Para conferir:
`git cat-file -p <sha> | grep -cE 'BEGIN (SSH|PGP) SIGNATURE'`. Os merges e squashes feitos
pelo GitHub vêm assinados por ele em PGP, não pela sua chave SSH, e também valem.

## Pull requests

- **Base `develop`**, exceto os PRs de release e de hotfix, que têm base `main` (Auto).
- **Título** no formato de commit (`feat(auth): add OAuth login`). PR de release:
  `release: vX.Y.Z`. PR de hotfix: `hotfix: vX.Y.Z` (Auto).
- **Corpo** pelo [template](.github/pull_request_template.md): problema, o que muda,
  verificação e `Refs #N`.
- Use `Refs #N`, **não** `Fixes #N`: o fechamento de uma issue pede o comentário de
  resolução, que o fechamento automático pula (ver [Issues](#issues-e-labels)).
- **Antes de abrir:** o comando `verify` do `.standards.json` passa localmente. É o mesmo
  que o CI roda; descobrir pelo workflow é mais lento. Quando o `verify` só roda numa
  máquina específica (Xcode num Mac, por exemplo), `verifyRunsIn: "local"` faz o CI pular
  e o resultado entra na seção Verificação do PR.

Checklist de todo PR para `develop`:

- [ ] Teste cobrindo a mudança. Numa correção, um teste que **falha sem ela**, com a
      regressão no título do teste.
- [ ] Documentação atualizada no mesmo PR.
- [ ] Entrada no `CHANGELOG.md`, em `[Unreleased]`, em PT e EN, descrevendo o impacto e não
      a mensagem do commit.
- [ ] Nada de [dado sensível](#dados-sensíveis) no diff.
- [ ] Decisão difícil de reverter tem ADR.

## Merge

**Confira a base antes de todo merge:** `gh pr view N --json baseRefName`. O hook recusa o
merge de PR com base `main` que não seja de release ou de hotfix (Bloqueado).

| PR | Método | Comando |
|---|---|---|
| branch curta → `develop` | merge commit | `gh pr merge N --merge --delete-branch` |
| release `develop` → `main` | squash | `gh pr merge N --squash --subject "release: vX.Y.Z" --body "<uma linha>"` |
| hotfix → `main` | squash | `gh pr merge N --squash --subject "hotfix: vX.Y.Z" --body "<uma linha>"` |

Sem `--subject`, a `main` fica com "título (#N)". Na `develop` não há `--subject`: o
repositório é configurado (`rulesets.sh`) para o merge commit levar o título e a descrição do
PR, que se leem melhor no `git log` que "Merge pull request #N from …".

A **branch padrão no GitHub é a `develop`** (`rulesets.sh` configura): PRs novos, inclusive os
do Dependabot, já nascem com a base certa. Um PR que chegar com base `main` sem ser de
release ou de hotfix muda de base com `gh pr edit N --base develop` antes do merge.

## Release

Roteiro executável: skill [`/release`](.claude/skills/release/SKILL.md). Os passos marcados
com **PARE** esperam a confirmação explícita do mantenedor.

1. **Tudo da versão está na `develop`**, com CI verde, e o `[Unreleased]` do CHANGELOG
   descreve tudo o que vai sair (`git log origin/main..origin/develop`).
2. **Escolha a versão** pelo SemVer (abaixo). **PARE:** versão e resumo para confirmação.
3. **PR `chore/bump-X.Y.Z`** para `develop`, com um commit `chore(release): X.Y.Z`:
   - os arquivos de `release.versionFiles`, editados à mão;
   - os comandos de `release.preBumpCommands`;
   - o `[Unreleased]` fechado como `[X.Y.Z] - AAAA-MM-DD`, com um `[Unreleased]` vazio acima.
4. **Gates do projeto** (`release.gates`): cada um é um **PARE**. Exemplo: validar um app
   num aparelho contra o ambiente de desenvolvimento.
5. **PR `develop` → `main`**, título `release: vX.Y.Z`, corpo `## 🇧🇷 Português`,
   `## 🇺🇸 English` (as seções da versão) e `## Verificação` no fim.
   **PARE** antes do squash.
6. **Tag anotada e assinada** no commit do squash:
   `git tag -s vX.Y.Z -m vX.Y.Z origin/main && git push origin vX.Y.Z` (Confirma).
7. **GitHub Release:**
   `gh release create vX.Y.Z --verify-tag --latest --title "vX.Y.Z — <frase PT> / <English phrase>" --notes-file <corpo do PR sem a Verificação>` (Confirma).
8. **`main` de volta para `develop`**, merge assinado:
   `git merge --no-ff -S origin/main -m "Merge branch 'main' into develop"` e push.
   Sem isso, a `develop` e a `main` divergem a cada release.
9. **Produção**, se o projeto tiver (`production.deployDoc`). **PARE:** só com autorização
   explícita.
10. **Avisar os repos irmãos**, se `xrepo.enabled`: uma issue de sync em cada um que consome
    algo deste.

Se a release sair e a produção não puder ir, abra uma issue para o deploy e não marque a
versão como implantada.

## Hotfix

Para um defeito **em produção** que não pode esperar, quando a `develop` já tem trabalho que
ainda não pode sair. Se a `develop` puder sair inteira, faça uma release patch normal.
Roteiro executável: skill [`/hotfix`](.claude/skills/hotfix/SKILL.md).

1. **Issue** do tipo `Bug` com Priority `Urgent`. **PARE:** confirmar que é hotfix e não release.
2. **Branch `hotfix/X.Y.Z`** a partir da **tag em produção**, não da `develop`:
   `git switch -c hotfix/1.4.1 v1.4.0`. Assim nada que está em andamento vai junto.
3. Na branch, nesta ordem: o teste que falha sem a correção, a correção, o bump de versão
   (`chore(release): X.Y.Z`) e a entrada no CHANGELOG já como `[X.Y.Z] - AAAA-MM-DD`.
4. **PR `hotfix/X.Y.Z` → `main`**, título `hotfix: vX.Y.Z`, corpo bilíngue com
   `## Verificação`. **PARE** antes do squash.
5. **Tag, GitHub Release e produção**, como nos passos 6, 7 e 9 da release.
6. **`main` de volta para `develop`**, como no passo 8 da release. No CHANGELOG da
   `develop`, a seção `[X.Y.Z]` fica **abaixo** do `[Unreleased]`, que continua com o que
   já estava lá. É o passo mais esquecido: sem ele, a próxima release apaga a correção.

O hotfix pula os gates longos da release (`release.gates`) só se o mantenedor disser; nunca
pula a tag, a confirmação de produção nem o merge de volta.

## Versionamento e CHANGELOG

[SemVer](https://semver.org/lang/pt-BR/): correção → patch; funcionalidade retrocompatível
→ minor; quebra de contrato ou de formato de dado → major, com o caminho de migração
descrito no CHANGELOG. Antes da 1.0.0, uma quebra sobe o minor.

O `CHANGELOG.md` segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e é
**bilíngue**: cada versão tem `### 🇧🇷 Português` e `### 🇺🇸 English`, com as mesmas
seções (`Adicionado/Added`, `Alterado/Changed`, `Corrigido/Fixed`, `Removido/Removed`,
`Segurança/Security`, `Documentação/Documentation`). A entrada descreve o efeito para quem
usa, não repete a mensagem do commit, e cita a issue (`(#123)`).

## Issues e labels

**Toda pendência vira issue**, no repositório onde o trabalho acontece, nunca item de um
`BACKLOG.md`, de um plano ou de uma lista de TODO. Um documento pode agrupar pendências
(um plano de correção, um roadmap), mas cada item aberto aponta para a sua issue. Use os
[templates](.github/ISSUE_TEMPLATE/): bug, funcionalidade, tarefa, documentação, pergunta
e, entre repositórios, pedido xrepo. Cada formulário já define o tipo da issue. Issue em
branco é desligada. Um
repositório que não segue o padrão recebe os mesmos formulários, sem o de xrepo, do
repositório público `.github` da conta.

Tipo e prioridade são **recursos nativos do GitHub**, definidos uma vez por conta ou
organização por `.standards/issue-types.sh setup`, a partir de `.standards/issue-types.json`:

| O quê | Valores | Regra |
|---|---|---|
| Tipo de issue | `Bug`, `Feature`, `Task`, `Docs`, `Question` | exatamente um |
| Campo Priority | `Urgent` (bloqueante ou risco ao usuário), `High` (quebrado, sem risco), `Medium` (melhoria relevante), `Low` (pode esperar) | exatamente um, definido na triagem |

`gh issue create --type <Tipo>` define o tipo; o `gh` não tem opção para campo de issue,
então a prioridade passa por `.standards/issue-types.sh priority <owner/repo> <n> <valor>`.
Busca: `type:Bug` e `field.priority:urgent`.

As labels cobrem o que o GitHub não tem de nativo. São as mesmas em todos os projetos,
criadas por `.standards/labels.sh`:

| Grupo | Labels | Regra |
|---|---|---|
| Contrato | `contract` | a mudança mexe num contrato que outro repositório consome |
| Estado | `status:needs-info`, `status:needs-decision`, `status:blocked` | zero ou mais |
| Verificação | `needs-verification` | resolvida, aguardando quem pediu |
| Entre repos | `xrepo`, `from:<repo>`, `parity` | só com `xrepo.enabled` |

Ciclo de uma issue:

1. Aberta com tipo; a prioridade é definida na triagem.
2. Branch com o número (`fix/123-slug`) e PR com `Refs #123`.
3. Depois do merge, um comentário de resolução e o fechamento:

   ```markdown
   ## Resolução

   - PR: #<n> (merge em `develop`, commit `<sha curto>`)
   - O que mudou: <1 a 3 linhas>
   - Ação necessária em outro repo: nenhuma | <o quê>
   - Sai em: `[Unreleased]` | `vX.Y.Z`
   ```

4. Se não vai fazer: comente o motivo e feche com `--reason "not planned"`.

**Entre repositórios** (`xrepo.enabled`), a issue mora no repo onde o trabalho acontece. O
roteiro executável, com os comandos, é a skill [`/xrepo`](.claude/skills/xrepo/SKILL.md):

- quem pede abre a issue no outro repo com tipo e as labels `xrepo` e `from:<este-repo>`,
  passados explicitamente no `gh issue create` (o que o template define só vale na web), e
  depois define a prioridade;
- quem trata comenta a resolução, adiciona `needs-verification` e fecha;
- quem pediu confere contra os critérios de aceite e remove `needs-verification`, ou reabre
  dizendo o que falta. **Quem pediu é o único que remove `needs-verification`; quem tratou é
  o único que fecha.**
- Conhecimento permanente (contrato, decisões) vive em documento versionado; a issue aponta
  para ele, não o substitui. Repos nunca escrevem arquivos um no outro.

## Documentação, ADR e auditorias

- **O código é a fonte da verdade.** Doc que cita número ou constante aponta para o arquivo
  em vez de repetir o valor.
- **Doc viva** (arquitetura, API, operação) cita nome de função, não `arquivo:linha`, que
  envelhece a cada mudança.
- **ADR** em [docs/adr/](docs/adr/) para decisão difícil de reverter, que alguém
  razoavelmente faria diferente, ou que o código sozinho não explica. Um ADR não é editado
  quando a decisão muda: escreve-se o próximo e marca-se o anterior como substituído.
- **Registro de auditoria** é retrato do código numa data: fica na pasta de
  `docs.auditDir` do `.standards.json` (padrão `docs/audits/`), como
  `AAAA-MM-DD-<assunto>.md` ou numa subpasta quando tem várias fases, diz no cabeçalho o
  commit que descreve, aponta os
  links de código para esse commit, usa um prefixo de ID que ainda não existe no repo
  (`git grep -wE '<PREFIXO>[0-9]{2}'` vazio) e cada achado pendente tem issue.

## Dependências

- **As Actions ficam fixadas num lockfile.** O `gh actions-lock` (extensão
  [github/gh-actions-lock](https://github.com/github/gh-actions-lock)) grava
  `.github/workflows/actions.lock`, com cada action, inclusive as transitivas, fixada num
  commit; o runner recusa um pin que não confere. Rode depois de incluir ou mudar um `uses:` e
  commite o lockfile junto com o workflow. A checagem `standards` confere em todo PR.
- **O Dependabot abre as atualizações** (`.github/dependabot.yml`, semeado uma vez e depois do
  projeto): um PR por ecossistema e por semana, minor e patch agrupados, com base na `develop`,
  com título `chore(deps): …`. Atualização de segurança chega sozinha, assim que sai o alerta.
  Acrescente um bloco para cada ecossistema que o projeto usa.
- Atualização de dependência entra como qualquer PR: CI verde, merge commit na `develop`.
- **As checagens rodam como uma action.** O `standards.yml` do projeto chama
  `diego-castilho/dev-standards/check@vX.Y.Z`, então a versão da tag é a versão cobrada, e o
  sync só troca essa tag. Se o repositório restringe as Actions permitidas, libere
  `diego-castilho/dev-standards/check@*`.

## Dados sensíveis

Nunca entram em commit, doc, issue, PR ou log, **mesmo com o repositório privado**:

- token, senha, chave, URL com credencial, `.env`;
- dado pessoal ou de cliente real (a lista do projeto fica em `sensitive` no
  `.standards.json`);
- IP real, nome de host interno ou topologia que permita chegar a um serviço. Em documento,
  use endereços de documentação (`192.0.2.x`, RFC 5737) ou o nome do serviço. O CI recusa
  IP de rede privada em Markdown (Auto, `check.sh docs`);
- fixture não higienizado: descreva o formato; o fixture higienizado entra pelo PR.

Dump de banco fica fora do repositório, com permissão `600`, e é apagado quando deixa de
servir como rollback.

## Idiomas

| O quê | Idioma |
|---|---|
| Commits, nomes de branch, labels, código e comentários de código | inglês |
| `CHANGELOG.md`, PR de release e de hotfix, GitHub Release | PT e EN |
| `README`, `CONTRIBUTING`, `SECURITY` | EN no `.md`, PT no `.pt-BR.md`, com as mesmas seções (Auto) |
| `CLAUDE.md`, `docs/`, ADR, issues | português |

<!-- standards:end -->

## Específico deste projeto

<!-- O que vale só aqui: regras de domínio, i18n, contrato, ambientes. Este trecho é do
     projeto; o sync do padrão nunca o altera. -->

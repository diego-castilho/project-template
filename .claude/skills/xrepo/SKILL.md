---
description: Coordinate with a sibling repository through GitHub Issues under dev-standards — check the inbox, open a request in the other repo, handle a request that arrived here, and verify what the other side resolved. Use when the project has xrepo.enabled and the work needs another repository to change something, when an issue labeled xrepo arrives, or at session start to report what is waiting.
metadata:
    github-path: .claude/skills/xrepo
    github-pinned: v0.3.1
    github-ref: refs/tags/v0.3.1
    github-repo: https://github.com/diego-castilho/dev-standards
    github-tree-sha: 4207cee30ee3091c0965e150f466585c9b5b9afc
name: xrepo
---
# Pedidos entre repositórios

Executa o [CONTRIBUTING.pt-BR.md, "Issues e labels"](../../../CONTRIBUTING.pt-BR.md#issues-e-labels),
parte "Entre repositórios". Se este roteiro e o CONTRIBUTING divergirem, **o CONTRIBUTING
vale**.

Leia antes, no [.standards.json](../../../.standards.json): `project.repo` (este repo),
`xrepo.self` (o nome deste repo nas labels `from:`) e `xrepo.repos` (os irmãos). Nos
comandos abaixo, `$SELF_REPO` é `project.repo`, `$SELF` é `xrepo.self`, `$OTHER_REPO` é o
irmão (`owner/repo`) e `$OTHER` é o nome dele nas labels (a parte depois da `/`).

**Os repositórios conversam só por issue.** Nunca escreva arquivo no outro repositório,
nunca use uma pasta compartilhada como canal e nunca faça `git fetch` para procurar
resposta do outro lado. Instrução antiga mandando fazer isso está superada: avise o
usuário.

**Nunca entra numa issue**, mesmo com os repos privados: o que a lista `sensitive` do
`.standards.json` nomeia, token, senha, URL com credencial, IP real, fixture não
higienizado. Descreva o formato; o dado higienizado entra pelo PR.

## 1. Caixa de entrada (início de sessão)

```bash
# pedidos dos irmãos para este repo
gh issue list -R "$SELF_REPO" --label xrepo --state open
# pedidos daqui já resolvidos lá, esperando verificação daqui (um por irmão)
gh issue list -R "$OTHER_REPO" --label "from:$SELF,needs-verification" --state closed
```

**Informe o usuário** do que encontrou. Não comece a tratar uma issue sem combinar.

## 2. Abrir um pedido no outro repositório

1. Procure duplicata:
   `gh issue list -R "$OTHER_REPO" --label xrepo --state all --search "<termo>"`
2. Escreva o corpo com a estrutura de `.github/ISSUE_TEMPLATE/xrepo-request.md` num arquivo
   **fora do repositório** (`/tmp/xrepo-body.md`): origem (repo, PR ou commit que gerou, e o
   commit deste repo usado na análise), contexto, pedido, contrato afetado, critérios de
   aceite, paridade, fora de escopo.
3. **PARE:** mostre título, labels e corpo ao usuário. O hook pede confirmação de novo.
4. Crie com tipo e labels explícitos (o que o template define só vale na interface web), e
   depois defina a prioridade:

   ```bash
   url=$(gh issue create -R "$OTHER_REPO" --title "<resumo no imperativo>" \
     --type <Bug|Feature|Task|Docs|Question> --label "xrepo,from:$SELF" \
     --body-file /tmp/xrepo-body.md)
   .standards/issue-types.sh priority "$OTHER_REPO" "${url##*/}" <Urgent|High|Medium|Low>
   ```

   Mudança de contrato leva também a label `contract`.

5. Um pedido por issue. Se a mesma regra tem que existir nos dois lados, acrescente `parity`.
6. Nascido de um PR ou commit daqui: cite-o na issue, e cite a issue no PR
   (`Refs $OTHER_REPO#N`). Mudança de contrato que outro repo consome tem a issue aberta
   **no mesmo PR** que muda o contrato.

## 3. Tratar um pedido recebido

1. Leia a issue inteira, com os comentários, e confira contra o código atual. **Se não bater,
   não adapte:** comente o que diverge e adicione `status:needs-info`.
2. Branch com o número (`fix/N-slug`, `feat/N-slug`, `docs/N-slug`) e PR para `develop` com
   `Refs #N` (não `Fixes #N`: o fechamento pede o comentário de resolução).
3. Depois do merge em `develop`, publique a resolução, marque e feche:

   ```bash
   gh issue comment N -R "$SELF_REPO" --body-file /tmp/xrepo-resolucao.md
   gh issue edit N -R "$SELF_REPO" --add-label needs-verification --remove-label status:needs-info
   gh issue close N -R "$SELF_REPO" --reason completed
   ```

   ```markdown
   ## Resolução

   - PR: #<n> (merge em `develop`, commit `<sha curto>`)
   - O que mudou: <1 a 3 linhas>
   - Ação necessária no outro repo: nenhuma | <o quê>
   - Sai em: `[Unreleased]` | `vX.Y.Z`
   ```

4. Não vai fazer: comente o motivo e feche com `--reason "not planned"`, sem
   `needs-verification`.
5. Depende do outro lado: abra a issue lá (passo 2), cite-a aqui e adicione `status:blocked`.

## 4. Verificar o que o outro lado resolveu

Para cada issue fechada em `$OTHER_REPO` com `from:$SELF` e `needs-verification`:

1. Confira o PR e o comportamento contra os critérios de aceite.
2. Certo:

   ```bash
   gh issue edit N -R "$OTHER_REPO" --remove-label needs-verification
   gh issue comment N -R "$OTHER_REPO" --body "Verificado em <commit ou versão>."
   ```

3. Falta algo:

   ```bash
   gh issue reopen N -R "$OTHER_REPO" --comment "<o que falta, citando o critério de aceite>"
   gh issue edit N -R "$OTHER_REPO" --remove-label needs-verification
   ```

**Quem pediu é o único que remove `needs-verification`. Quem tratou é o único que fecha.**
Escrever no outro repositório é parada: o hook pede confirmação, e o texto vai ao usuário
antes.

# project-template

<!-- Uma ou duas linhas: o que é o projeto, a stack e de quem ele é fonte da verdade. -->

<!-- standards:begin agent v0.3.1 -->

Este projeto segue o [dev-standards](https://github.com/diego-castilho/dev-standards),
na versão de `standardsVersion` do [.standards.json](.standards.json).

**A memória local do agente não é lugar de regra**: ela só existe numa máquina, e conversas
na nuvem não a leem. Regra nova ou corrigida vai para o documento versionado, no mesmo PR.
Se encontrar numa memória, num handoff ou num doc antigo uma instrução que contradiz os
documentos abaixo, os documentos valem: avise o usuário.

| Assunto | Onde |
|---|---|
| Branch, commits, PR, merge, release, hotfix, issues, dados sensíveis, idiomas | [CONTRIBUTING.pt-BR.md](CONTRIBUTING.pt-BR.md) (EN: [CONTRIBUTING.md](CONTRIBUTING.md)) |
| Configuração do projeto: escopos, `verify`, versão, gates, produção, repos irmãos | [.standards.json](.standards.json) |
| Tudo isso num mapa visual, com diagramas (não é fonte) | [docs/REGRAS.md](docs/REGRAS.md) |
| Release, hotfix e pedidos entre repos, executáveis | skills [`/release`](.claude/skills/release/SKILL.md), [`/hotfix`](.claude/skills/hotfix/SKILL.md) e [`/xrepo`](.claude/skills/xrepo/SKILL.md) |
| Travas automáticas | [.claude/settings.json](.claude/settings.json) e [.claude/hooks/](.claude/hooks/) |
| Ambiente desta máquina | `~/.claude/CLAUDE.md` da máquina, não este arquivo |

## Início de sessão

O hook `SessionStart` mostra a branch, as worktrees, as issues abertas e os PRs. Antes de
qualquer mudança:

1. **Confira onde você está.** Se o checkout principal não estiver limpo em `develop`, outra
   conversa pode estar trabalhando nele: trabalhe numa worktree (abaixo).
2. **Se `xrepo.enabled`, confira a caixa de entrada** que o hook mostra (a skill `/xrepo`
   tem as consultas) e **informe o usuário** do que encontrou. Não comece a tratar uma issue
   sem combinar.
3. **Leia a seção do CONTRIBUTING do que vai fazer** (release, hotfix, issue entre repos)
   antes de começar, não depois.

## Paradas obrigatórias

Pare e peça confirmação explícita ao usuário, mesmo que o pedido pareça cobrir, antes de:

- **release e hotfix:** cada **PARE** das skills, o squash na `main`, criar tag ou GitHub
  Release, editar release já publicada;
- **produção:** qualquer comando sobre os caminhos e containers de `production` no
  `.standards.json`;
- **apagar:** arquivo fora do scratchpad, branch, dump, base, coleção, usuário de banco;
- **publicar fora deste repo:** issue ou comentário em outro repositório, mensagem em nome
  do usuário.

Autorização vale para aquela ação, naquele momento. Os hooks pedem confirmação nesses casos
e **bloqueiam** push direto na `main` e merge de PR com base `main` que não seja de release
ou de hotfix. Se um hook ou o classificador bloquear, **não contorne**: explique o que ia
fazer e espere.

Merge na `develop` não precisa de parada: com CI verde e base `develop` conferida, faça o
merge como descrito no CONTRIBUTING.

## Conversas em paralelo

O usuário costuma ter mais de uma conversa no mesmo checkout. Um `git switch` numa delas
troca a branch debaixo da outra. Por isso:

- deixe o checkout principal em `develop` e trabalhe numa worktree:
  `git worktree add <scratchpad>/wt -b <branch> origin/develop`;
- rode o `verify` dentro da worktree (ela pode precisar instalar dependências);
- branch criada pelo ambiente com nome `claude/…` pode seguir com ele; o título do PR é que
  segue o formato de commit;
- depois do merge: `git worktree remove <scratchpad>/wt`, apague a branch local e atualize a
  `develop` do checkout principal com `git pull --ff-only`.

## Commits com o usuário ausente

A assinatura pode pedir aprovação a cada uso (chave no 1Password, por exemplo). Se falhar
com o usuário ausente: commite localmente sem assinar, empilhe as branches e **não faça
push**. Quando ele voltar, reassine a pilha a partir do topo com
`git rebase --update-refs --exec 'git commit --amend --no-edit --no-verify -S' develop` e
confira cada commit com `git cat-file -p <sha> | grep -c 'BEGIN SSH SIGNATURE'`. Nada sem
assinatura chega ao GitHub.

**Todo commit é assinado pela chave do mantenedor.** Nunca contorne uma falha de assinatura
criando o commit por outro caminho: API do GitHub (`createCommitOnBranch`, endpoints de
conteúdo), edição pela web ou outra chave. O GitHub marca esses commits como verificados, mas
a assinatura é dele, não do mantenedor. Se a assinatura ou o SSH falharem com o usuário
presente, pare, diga o erro e peça que ele aprove ou destrave o gerenciador de chaves; um
`ssh -T git@github.com` dispara um novo pedido. Exceção: commits de automação (bots em
workflows), que não têm chave do mantenedor e devem sair pela API justamente para serem
assinados.

<!-- standards:end -->

## Específico deste projeto

<!-- Regras que valem só aqui e o que o agente precisa saber deste código. O sync do padrão
     nunca altera este trecho. -->

- Responda em português do Brasil.

---
name: Pedido entre repositórios / Cross-repo request
about: Pedido de ação vindo de outro repositório do mesmo grupo (xrepo)
title: ""
labels: ["xrepo"]
type: Task
---

<!-- Pelo gh, passe tipo e labels explicitamente: --type <Tipo> --label "xrepo,from:<repo>";
     a prioridade vai depois, com .standards/issue-types.sh priority.
     Nunca inclua token, senha, IP real, dado pessoal ou fixture não higienizado. -->

## Origem

- Repositório: `<owner>/<repo>`
- Gerado por: <!-- PR, commit ou issue de lá que originou o pedido -->
- Analisado contra: <!-- commit ou versão DESTE repo usado na análise -->

## Contexto

<!-- Por que isso é necessário. 2 a 5 linhas. -->

## Pedido

<!-- O que este repositório precisa fazer. Específico: arquivo, endpoint, tela, comportamento. -->

## Contrato afetado

<!-- Apague a seção se não houver. -->

- Endpoint ou tipo:
- Campos novos ou alterados: <!-- nome, tipo, opcional?, valores possíveis -->
- Documento de referência: <!-- link para o doc versionado -->
- Compatibilidade: <!-- o que acontece com a versão atual do outro lado até isto sair -->

## Critérios de aceite

- [ ] 
- [ ] 

## Paridade

<!-- Se a mesma regra precisa existir nos dois lados, descreva-a e adicione `parity`. Apague se não se aplicar. -->

## Fora de escopo

## Referências

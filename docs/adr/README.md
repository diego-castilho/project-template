# Registros de decisão de arquitetura (ADR)

Decisões que moldaram o sistema e que não são óbvias lendo o código. Cada uma registra o
contexto, a decisão, as alternativas descartadas e as consequências, inclusive as ruins.

Um ADR não é documentação de uso. Ele responde **por que é assim** e o que aconteceria se
fosse diferente.

| # | Decisão | Status |
|---|---|---|
| [0001](0001-recursos-nativos-do-github-primeiro.md) | Recursos nativos do GitHub primeiro; script só onde o GitHub não chega | aceita |

## Quando escrever

Quando a decisão for difícil de reverter, quando alguém razoavelmente faria diferente, ou
quando o código sozinho não explica a escolha. Mudança de biblioteca, formato de dado
persistido, contrato de API e modelo de segurança costumam entrar. Nome de variável, não.

## Como

Copie [0000-template.md](0000-template.md) para `NNNN-<slug-em-kebab-case>.md`, com o
próximo número, e acrescente a linha na tabela acima no mesmo PR. Um ADR não é editado
quando a decisão muda: escreva o próximo, marque o anterior como substituído e aponte para o
novo.

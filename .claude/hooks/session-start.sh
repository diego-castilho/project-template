#!/usr/bin/env bash
# ============================================================================
# SessionStart hook — where am I, and what is waiting
# Part of dev-standards (CLAUDE.md, "Início de sessão").
# ============================================================================
# Prints, as context for the conversation: the branch and state of this
# checkout, other worktrees (a sign another conversation works here), the
# open issues and PRs, and — with xrepo.enabled — the cross-repo inbox and
# the requests waiting for verification. Never fails the session.
# ============================================================================
set -u
# macOS has no `timeout`; fall back to gtimeout or run without a limit.
t() { local s="$1"; shift; if command -v timeout >/dev/null 2>&1; then timeout "$s" "$@";
      elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$s" "$@"; else "$@"; fi; }
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

config=".standards.json"
cfg() { [ -f "$config" ] && jq -r "$1" "$config" 2>/dev/null; }
repo="$(cfg '.project.repo // empty')"
self="$(cfg '.xrepo.self // empty')"
xrepo="$(cfg '.xrepo.enabled // false')"

gh_bin="$(command -v gh || echo "$HOME/.local/bin/gh")"
or_none() { local x; x="$(cat)"; [ -n "$x" ] && printf '%s\n' "$x" || echo "- nenhuma"; }
gh_ok() { [ -x "$gh_bin" ] && [ -n "$repo" ] && t 10 "$gh_bin" auth status >/dev/null 2>&1; }

out="$({
  echo "## Estado do checkout (hook SessionStart)"
  echo
  echo "- Diretório: $(pwd)"
  branch="$(git branch --show-current 2>/dev/null || echo '?')"
  echo "- Branch: ${branch}"
  changes="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  echo "- Arquivos modificados: ${changes}"
  wts="$(git worktree list 2>/dev/null | wc -l | tr -d ' ')"
  if [ "${wts:-1}" -gt 1 ]; then
    echo "- Worktrees: ${wts}. Outra conversa pode estar trabalhando neste repositório:"
    git worktree list 2>/dev/null | sed 's/^/  - /'
  fi
  if [ "$branch" != "develop" ] || [ "${changes:-0}" != "0" ]; then
    echo "- **Atenção:** o checkout não está limpo em develop. Se as mudanças não são suas, trabalhe numa worktree (CLAUDE.md, Conversas em paralelo)."
  fi
  if [ ! -f "$config" ]; then
    echo "- **Atenção:** sem .standards.json. Rode .standards/bootstrap.sh."
  fi
  echo
  if gh_ok; then
    echo "## Issues e PRs (${repo})"
    echo
    echo "Issues abertas (até 15):"
    t 15 "$gh_bin" issue list -R "$repo" --state open --limit 15 \
      --json number,title,labels -q '.[] | "- #\(.number) \(.title) [\([.labels[].name] | join(", "))]"' 2>/dev/null | or_none
    echo
    echo "PRs abertos:"
    t 15 "$gh_bin" pr list -R "$repo" --state open \
      --json number,title,baseRefName -q '.[] | "- #\(.number) → \(.baseRefName): \(.title)"' 2>/dev/null | or_none
    if [ "$xrepo" = "true" ]; then
      echo
      echo "## Coordenação entre repositórios"
      echo
      echo "Caixa de entrada (xrepo abertas aqui):"
      t 15 "$gh_bin" issue list -R "$repo" --label xrepo --state open \
        --json number,title -q '.[] | "- #\(.number) \(.title)"' 2>/dev/null | or_none
      while IFS= read -r other; do
        [ -z "$other" ] && continue
        echo
        echo "Pedidos daqui resolvidos em ${other}, aguardando verificação:"
        t 15 "$gh_bin" issue list -R "$other" --label "from:${self},needs-verification" --state closed \
          --json number,title -q ".[] | \"- ${other}#\(.number) \(.title)\"" 2>/dev/null | or_none
      done < <(cfg '.xrepo.repos[]?')
    fi
    echo
    echo "Informe o usuário do que encontrou acima e não comece a tratar uma issue sem combinar."
  else
    echo "gh indisponível, sem login ou sem project.repo no .standards.json: consulte issues e PRs à mão."
  fi
  echo
  echo "Antes de release, hotfix, produção ou apagar algo: CLAUDE.md, \"Paradas obrigatórias\"."
} 2>/dev/null)"

jq -cn --arg c "$out" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
exit 0

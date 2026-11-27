#!/usr/bin/env bash
# ============================================================================
# PreToolUse hook (Bash) — the mandatory stops of CLAUDE.md, enforced
# Part of dev-standards (CONTRIBUTING.md, "Merge", "Release", "Hotfix").
# ============================================================================
# Reads the hook payload on stdin and answers with a permission decision:
#
#   deny — never allowed, whatever the conversation thinks it was told:
#          a push that writes to `main`, and merging a PR whose base is
#          `main` unless it is a release or hotfix PR
#          (title "release: vX.Y.Z" or "hotfix: vX.Y.Z").
#   ask  — the maintainer confirms each time: tags, GitHub releases, the
#          squash into main, production (paths and containers listed in
#          .standards.json), deletions outside the scratchpad, database
#          drops, and writes to sibling repositories (xrepo.repos).
#
# Anything else passes silently (exit 0, no output).
# Test: .standards/test-guard-bash.sh
# ============================================================================
set -uo pipefail
# macOS has no `timeout`; fall back to gtimeout or run without a limit.
t() { local s="$1"; shift; if command -v timeout >/dev/null 2>&1; then timeout "$s" "$@";
      elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$s" "$@"; else "$@"; fi; }

payload="$(cat)"
cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -z "$cmd" ] && exit 0

config="${STANDARDS_CONFIG:-${CLAUDE_PROJECT_DIR:-.}/.standards.json}"
cfg() { [ -f "$config" ] && jq -r "$1" "$config" 2>/dev/null; }

decide() { # $1 = deny|ask, $2 = reason
  jq -cn --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
  exit 0
}

has() { printf '%s' "$cmd" | grep -qE -- "$1"; }
# The command without redirections to /dev/null, to spot real writes.
has_w() { printf '%s' "$cmd" | sed -E 's#[0-9&]?>>?[[:space:]]*/dev/null##g' | grep -qE -- "$1"; }
re_escape() { printf '%s' "$1" | sed -E 's/[][\.^$*+?(){}|/]/\\&/g'; }

# ── deny ────────────────────────────────────────────────────────────────────
# A push whose refspec writes to main: "git push origin main", "HEAD:main",
# "+main", "--delete main". Tags and other branches are not matched.
if has '(^|[;&|[:space:]])git[[:space:]]+push\b' && \
   has 'git[[:space:]]+push\b[^;&|]*([[:space:]]|:|\+)(refs/heads/)?main([[:space:]]|$|;|&|\|)'; then
  decide deny "Push direto na main é proibido (CONTRIBUTING, Fluxo de branches). A main só muda pelo squash de um PR de release ou de hotfix."
fi

# Force-push to develop.
if has 'git[[:space:]]+push\b[^;&|]*(--force|-f\b|--force-with-lease)' && \
   has 'git[[:space:]]+push\b[^;&|]*([[:space:]]|:|\+)(refs/heads/)?develop([[:space:]]|$|;|&|\|)'; then
  decide deny "Force-push na develop é proibido (CONTRIBUTING, Fluxo de branches)."
fi

# gh pr merge: look at the PR's base. Only release and hotfix PRs may target main.
if has '(^|[;&|[:space:]])gh[[:space:]]+pr[[:space:]]+merge\b'; then
  pr="$(printf '%s' "$cmd" | grep -oE 'gh[[:space:]]+pr[[:space:]]+merge[[:space:]]+([^-[:space:]][^[:space:]]*)' | awk '{print $4}' | head -1)"
  repo="$(printf '%s' "$cmd" | grep -oE -- '(-R|--repo)[[:space:]=]+[^[:space:]]+' | awk -F'[[:space:]=]+' '{print $2}' | head -1)"
  gh_bin="$(command -v gh || echo "$HOME/.local/bin/gh")"
  info="${STANDARDS_TEST_PR_INFO:-}"
  if [ -z "$info" ] && [ -n "$pr" ] && [ -x "$gh_bin" ]; then
    info="$(t 15 "$gh_bin" pr view "$pr" ${repo:+-R "$repo"} --json baseRefName,title -q '.baseRefName + "\t" + .title' 2>/dev/null)"
  fi
  base="${info%%$'\t'*}"; title="${info#*$'\t'}"
  if [ -z "$info" ]; then
    decide ask "Não consegui conferir a base do PR ${pr:-?}. Confirme que ela é develop (ou que é o PR de release ou de hotfix) antes do merge."
  elif [ "$base" = "main" ]; then
    case "$title" in
      release:\ v*|hotfix:\ v*) decide ask "Squash na main ($title). Confirme que os gates foram cumpridos (CONTRIBUTING, Release/Hotfix) antes de seguir." ;;
      *) decide deny "O PR $pr tem base main e não é de release nem de hotfix. Retarget para develop: gh pr edit $pr --base develop (CONTRIBUTING, Merge)." ;;
    esac
  fi
fi

# ── ask: release ────────────────────────────────────────────────────────────
if has '(^|[;&|[:space:]])git[[:space:]]+tag[[:space:]]+(-[asfdmu]|v[0-9])'; then
  decide ask "Criar, mover ou apagar tag é passo de release: confirme (CONTRIBUTING, Release, passo 6)."
fi
if has 'git[[:space:]]+push\b[^;&|]*([[:space:]]v[0-9]+\.[0-9]+|refs/tags/|--tags)'; then
  decide ask "Push de tag publica a versão: confirme (CONTRIBUTING, Release, passo 6)."
fi
if has '(^|[;&|[:space:]])gh[[:space:]]+release[[:space:]]+(create|edit|delete|upload)\b'; then
  decide ask "GitHub Release cria ou altera uma versão publicada: confirme (CONTRIBUTING, Release, passo 7)."
fi

# ── ask: production (from .standards.json) ────────────────────────────────
while IFS= read -r p; do
  [ -z "$p" ] && continue
  home_alt='(~|\$HOME|/home/[^/[:space:]]+|/Users/[^/[:space:]]+)'
  # shellcheck disable=SC2088 # a literal "~/" from the config, not an expansion
  case "$p" in
    "~/"*) p_re="${home_alt}/$(re_escape "${p#\~/}")" ;;
    *)     p_re="$(re_escape "$p")" ;;
  esac
  # Reading is fine (ls, cat, logs); changing state is not.
  if has "$p_re" && has_w '(docker([[:space:]]+compose|-compose)?\b([^;&|]*[[:space:]])?(up|down|restart|stop|start|rm|kill|pull|build|exec|run|create|cp)\b|(^|[;&|[:space:]])(cp|mv|tee|rm|ln|chmod|chown)[[:space:]]|sed[[:space:]]+-i|>[[:space:]]*[^&[:space:]])'; then
    decide ask "Comando que altera um caminho de produção ($p): produção só com autorização explícita (CLAUDE.md, Paradas obrigatórias)."
  fi
done < <(cfg '.production.paths[]?')
while IFS= read -r c; do
  [ -z "$c" ] && continue
  if has "docker([[:space:]]+compose)?[[:space:]]+(exec|restart|stop|start|kill|rm|update|cp|pause|unpause|up|down)\b[^;&|]*[[:space:]]$(re_escape "$c")([[:space:]:]|$)"; then
    decide ask "Comando sobre o container de produção $c: confirme (CLAUDE.md, Paradas obrigatórias)."
  fi
done < <(cfg '.production.containers[]?')

# ── ask: deletions ──────────────────────────────────────────────────────────
# rm of anything outside /tmp (the scratchpad lives under /tmp).
if has '(^|[;&|[:space:]])(command[[:space:]]+|\\)?rm[[:space:]]'; then
  targets="$(printf '%s' "$cmd" | grep -oE '(^|[;&|[:space:]])(command[[:space:]]+|\\)?rm([[:space:]]+-[^[:space:]]+)*([[:space:]]+[^;&|[:space:]]+)+' \
    | sed -E 's/^[;&|[:space:]]*(command[[:space:]]+|\\)?rm//' | tr ' ' '\n' | grep -vE '^(-|$)')"
  if printf '%s\n' "$targets" | grep -qvE '^/(private/)?tmp/'; then
    decide ask "Apagar arquivo fora do scratchpad: confirme (CLAUDE.md, Paradas obrigatórias)."
  fi
fi
if has 'git[[:space:]]+push\b[^;&|]*(--delete|[[:space:]]:[^[:space:]])' || has 'git[[:space:]]+branch[[:space:]]+-D\b'; then
  decide ask "Apagar branch remota ou forçar a remoção de branch local: confirme que nada se perde (git branch -r --no-merged origin/develop)."
fi
if has '(dropDatabase|dropUser|dropIndex|\.drop\(|deleteMany|dropCollection|DROP[[:space:]]+(TABLE|DATABASE|SCHEMA)|TRUNCATE[[:space:]])'; then
  decide ask "Remoção no banco (base, tabela, coleção, índice, usuário ou documentos): confirme."
fi

# ── ask: writing to sibling repositories ────────────────────────────────────
if has 'gh[[:space:]]+(issue|pr)[[:space:]]+(create|comment|edit|close|reopen)\b'; then
  while IFS= read -r r; do
    [ -z "$r" ] && continue
    if has "$(re_escape "$r")"; then
      decide ask "Escrita em outro repositório ($r): confirme o texto antes de publicar (CLAUDE.md, Paradas obrigatórias)."
    fi
  done < <(cfg '.xrepo.repos[]?')
fi

exit 0

#!/usr/bin/env bash
# ============================================================================
# dev-standards checks — the "Auto" rules of CONTRIBUTING.md
# ============================================================================
# Usage:
#   check.sh config                         .standards.json is valid
#   check.sh branch  <head> <base>          branch name and base (Fluxo de branches)
#   check.sh title   <title> <head> <base>  PR title (Pull requests)
#   check.sh subject <subject>              one commit subject (Commits)
#   check.sh commits <base-sha> <head-sha>  commit subjects in the range (Commits)
#   check.sh bilingual                      EN/PT pairs have the same sections (Idiomas)
#   check.sh docs                           no private network address in Markdown
#   check.sh all-local                      config + bilingual + docs (what verify runs)
#
# Exit status 1 on any violation; each one is printed as "✗ <rule>: <detail>",
# and warnings that do not fail as "⚠ <rule>: <detail>".
# Runs on Linux and macOS with bash, git, jq, grep and sed only.
# ============================================================================
set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" || exit 2

config="${STANDARDS_CONFIG:-.standards.json}"
errors=0
err()  { printf '✗ %s\n' "$*" >&2; errors=$((errors+1)); }
warn() { printf '⚠ %s\n' "$*" >&2; }
ok()   { printf '✓ %s\n' "$*"; }

TYPES='feat|fix|perf|refactor|style|docs|test|build|ci|chore|revert'
SCOPED_TYPES='feat|fix|perf|refactor'
BRANCH_PREFIXES='feat|fix|docs|refactor|perf|test|chore|ci|build'
SEMVER='[0-9]+\.[0-9]+\.[0-9]+'
SUBJECT_AIM=72
SUBJECT_MAX=100

scopes_re() {
  local s
  s="$(jq -r '(.commitScopes // []) | join("|")' "$config" 2>/dev/null)"
  printf '%s' "${s:-[a-z0-9-]+}"
}

check_config() {
  if [ ! -f "$config" ]; then err "config: $config não existe (rode .standards/install.sh)"; return; fi
  if ! jq empty "$config" 2>/dev/null; then err "config: $config não é JSON válido"; return; fi
  local k before=$errors
  for k in standardsVersion project.name project.repo commitScopes verify release production xrepo; do
    jq -e ".${k} != null" "$config" >/dev/null 2>&1 || err "config: falta a chave '${k}' em $config"
  done
  jq -e '(.commitScopes | type) == "array" and (.commitScopes | length) > 0' "$config" >/dev/null 2>&1 \
    || err "config: commitScopes precisa ser uma lista não vazia"
  jq -e '(.verifyRunsIn // "ci") | IN("ci", "local")' "$config" >/dev/null 2>&1 \
    || err "config: verifyRunsIn é \"ci\" ou \"local\""
  [ "$errors" -eq "$before" ] && ok "config: $config válido"
}

check_branch() { # head base
  local head="$1" base="$2" before=$errors
  case "$base" in
    main)
      if [[ "$head" =~ ^hotfix/${SEMVER}$ ]] || [ "$head" = "develop" ]; then :; else
        err "branch: só develop (release) e hotfix/X.Y.Z abrem PR para a main; '$head' deve ir para a develop"
      fi ;;
    develop)
      if [[ "$head" =~ ^hotfix/ ]]; then
        err "branch: hotfix vai para a main, não para a develop"
      elif [ "$head" = "main" ] || [[ "$head" =~ ^claude/[A-Za-z0-9._/-]+$ ]] || [[ "$head" =~ ^dependabot/ ]]; then
        :   # merge de volta por PR, branch do Claude Code na nuvem, Dependabot
      elif ! [[ "$head" =~ ^(${BRANCH_PREFIXES})/([0-9]+-)?[a-z0-9][a-z0-9.-]*$ ]]; then
        err "branch: '$head' fora do formato <prefixo>/<issue>-<slug> (prefixos: ${BRANCH_PREFIXES//|/, })"
      fi ;;
    *) err "branch: base '$base' não é develop nem main (PR empilhado? mude a base antes do merge)" ;;
  esac
  [ "$errors" -eq "$before" ] && ok "branch: $head → $base"
}

check_subject() { # label subject
  local what="$1" s="$2" sc type scope
  sc="$(scopes_re)"
  # Subjects that are not Conventional Commits on purpose.
  if [[ "$s" =~ ^(release|hotfix):\ v${SEMVER}$ ]] || [[ "$s" =~ ^Revert\ \" ]]; then return 0; fi
  if [[ "$s" =~ ^(fixup|squash|amend)! ]]; then err "$what: '$s' precisa de autosquash antes do merge"; return 0; fi

  if (( ${#s} > SUBJECT_MAX )); then err "$what: assunto com ${#s} caracteres (máximo ${SUBJECT_MAX}): $s"
  elif (( ${#s} > SUBJECT_AIM )); then warn "$what: assunto com ${#s} caracteres (alvo ${SUBJECT_AIM}): $s"; fi
  if [[ "$s" =~ \.$ ]]; then err "$what: assunto termina com ponto: $s"; fi

  if ! [[ "$s" =~ ^(${TYPES})(\(([^\)]*)\))?!?:\ [^[:space:]] ]]; then
    err "$what: fora do Conventional Commits (<tipo>(<escopo>): <assunto>; tipos: ${TYPES//|/, }): $s"; return 0
  fi
  type="${BASH_REMATCH[1]}"; scope="${BASH_REMATCH[3]}"
  if [ -z "$scope" ]; then
    if [[ "$type" =~ ^(${SCOPED_TYPES})$ ]]; then err "$what: '$type' exige escopo (${sc//|/, }): $s"; fi
  elif ! [[ "$scope" =~ ^(${sc})$ ]]; then
    err "$what: escopo '$scope' fora de commitScopes (${sc//|/, }): $s"
  fi
  return 0
}

check_title() { # title head base
  local title="$1" head="$2" base="$3" before=$errors
  if [ "$base" = "main" ]; then
    if [ "$head" = "develop" ]; then
      [[ "$title" =~ ^release:\ v${SEMVER}$ ]] || err "título: PR de release é 'release: vX.Y.Z', não '$title'"
    elif [[ "$head" =~ ^hotfix/(${SEMVER})$ ]]; then
      [ "$title" = "hotfix: v${BASH_REMATCH[1]}" ] || err "título: PR de hotfix é 'hotfix: v${BASH_REMATCH[1]}', não '$title'"
    fi
  elif [ "$head" = "main" ]; then
    :
  else
    check_subject "título" "$title"
  fi
  [ "$errors" -eq "$before" ] && ok "título: $title"
}

check_commits() { # base head
  local range="$1..$2" before=$errors n=0 s
  while IFS= read -r s; do
    [ -z "$s" ] && continue
    n=$((n+1))
    check_subject "commit" "$s"
  done < <(git log --no-merges --format='%s' "$range")
  [ "$errors" -eq "$before" ] && ok "commits: $n no intervalo, todos no formato"
}

check_bilingual() {
  local before=$errors f pt en_h pt_h pairs=0
  for f in README.md CONTRIBUTING.md SECURITY.md; do
    pt="${f%.md}.pt-BR.md"
    [ -f "$f" ] || [ -f "$pt" ] || continue
    pairs=$((pairs+1))
    if [ ! -f "$f" ] || [ ! -f "$pt" ]; then err "idiomas: $f e $pt precisam existir juntos"; continue; fi
    en_h="$(grep -E '^#{1,4} ' "$f" | sed -E 's/^(#+).*/\1/' | tr '\n' ' ')"
    pt_h="$(grep -E '^#{1,4} ' "$pt" | sed -E 's/^(#+).*/\1/' | tr '\n' ' ')"
    if [ "$en_h" != "$pt_h" ]; then
      err "idiomas: $f e $pt têm estruturas de seção diferentes ($(grep -cE '^#{1,4} ' "$f") × $(grep -cE '^#{1,4} ' "$pt") títulos)"
    fi
  done
  [ "$errors" -eq "$before" ] && ok "idiomas: $pairs par(es) EN/PT com as mesmas seções"
}

# Private network addresses (RFC 1918) in tracked Markdown. Documentation
# addresses (192.0.2.x, 198.51.100.x, 203.0.113.x, RFC 5737) pass. A line that
# must keep one (rare) ends with "<!-- ip-ok -->".
check_docs() {
  local before=$errors hits h
  hits="$(git ls-files -z '*.md' 2>/dev/null | xargs -0 grep -HnE \
    '(^|[^0-9.])(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3})([^0-9]|$)' \
    2>/dev/null | grep -v 'ip-ok -->' || true)"
  if [ -n "$hits" ]; then
    while IFS= read -r h; do err "dados sensíveis: IP de rede privada em Markdown: $(printf '%s' "$h" | cut -d: -f1-2)"; done <<< "$hits"
  fi
  [ "$errors" -eq "$before" ] && ok "dados sensíveis: nenhum IP de rede privada em Markdown"
}

case "${1:-}" in
  config)    check_config ;;
  branch)    check_branch "${2:?head}" "${3:?base}" ;;
  title)     check_title "${2:?title}" "${3:?head}" "${4:?base}" ;;
  subject)   b=$errors; check_subject "commit" "${2:?subject}"; [ "$errors" -eq "$b" ] && ok "commit: ${2}" ;;
  commits)   check_commits "${2:?base}" "${3:?head}" ;;
  bilingual) check_bilingual ;;
  docs)      check_docs ;;
  all-local) check_config; check_bilingual; check_docs ;;
  *) sed -n '2,18p' "$0"; exit 2 ;;
esac
[ "$errors" -eq 0 ]

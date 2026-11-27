#!/usr/bin/env bash
# ============================================================================
# Issue types and the Priority field (CONTRIBUTING, "Issues and labels").
# GitHub keeps both at the account or organization level, so one run serves
# every repository of the owner. Definitions: .standards/issue-types.json.
#
#   setup    [owner]              creates or updates the types and the field
#   migrate  [owner/repo]         copies type:* / priority:* (and the GitHub
#                                 default labels bug, enhancement, ...) into
#                                 the issue type and the Priority field. It
#                                 never removes a label and never overwrites
#                                 a type or a priority already set.
#   priority <owner/repo> <n> <Urgent|High|Medium|Low>
#                                 sets an issue's Priority (gh has no flag)
#
# Options: --dry-run (setup and migrate). Needs gh with the "user" scope for
# a personal account (gh auth refresh -s user) or admin on the organization.
# ============================================================================
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
defs=".standards/issue-types.json"
config=".standards.json"
api() { gh api -H "X-GitHub-Api-Version: 2026-03-10" "$@"; }

dry=0; args=()
for a in "$@"; do case "$a" in --dry-run) dry=1 ;; *) args+=("$a") ;; esac; done
set -- "${args[@]+"${args[@]}"}"
cmd="${1:-}"; shift || true
run() { if [ "$dry" -eq 1 ]; then printf '  (dry-run) %s\n' "$*"; else "$@" >/dev/null; fi; }
pause() { [ "$dry" -eq 1 ] || sleep 1; }   # GitHub asks for 1 s between mutations

default_repo() { jq -r '.project.repo // empty' "$config"; }

# Base path for an owner: the authenticated user (/user) or an organization.
base_for() {
  local owner="$1" kind me
  kind="$(api "users/$owner" --jq .type)"
  if [ "$kind" = "Organization" ]; then echo "orgs/$owner"; return; fi
  me="$(api user --jq .login)"
  [ "$me" = "$owner" ] || { echo "Tipos de issue de $owner só podem ser criados logado como $owner." >&2; exit 2; }
  echo "user"
}

field_id() { # base
  api "$1/issue-fields" --jq ".[] | select(.name == \"$(jq -r .priority.name "$defs")\") | .id"
}

setup() {
  local owner="${1:-$(default_repo | cut -d/ -f1)}" base existing
  [ -n "$owner" ] || { echo "Informe o dono ou defina project.repo em $config" >&2; exit 2; }
  base="$(base_for "$owner")"
  echo "Tipos de issue de $owner$([ "$dry" -eq 1 ] && echo ' (dry-run)'):"
  existing="$(api "$base/issue-types")"
  jq -c '.types[]' "$defs" | while IFS= read -r t; do
    local name id cur
    name="$(jq -r .name <<<"$t")"
    id="$(jq -r --arg n "$name" '.[] | select(.name == $n) | .id' <<<"$existing")"
    body="$(jq -c '{name, description, color, is_enabled: true}' <<<"$t")"
    if [ -z "$id" ]; then
      run api -X POST "$base/issue-types" --input - <<<"$body"; echo "  criado: $name"; pause
    else
      cur="$(jq -c --arg n "$name" '.[] | select(.name == $n) | {name, description, color, is_enabled}' <<<"$existing")"
      if [ "$cur" = "$body" ]; then echo "  igual: $name"
      else run api -X PUT "$base/issue-types/$id" --input - <<<"$body"; echo "  atualizado: $name"; pause; fi
    fi
  done

  echo "Campo $(jq -r .priority.name "$defs"):"
  local fid fields
  fields="$(api "$base/issue-fields")"
  fid="$(jq -r --arg n "$(jq -r .priority.name "$defs")" '.[] | select(.name == $n) | .id' <<<"$fields")"
  if [ -z "$fid" ]; then
    run api -X POST "$base/issue-fields" --input - <<<"$(jq -c '.priority | {name, description, visibility, data_type: "single_select", options}' "$defs")"
    echo "  criado"
  else
    local now want opts
    now="$(jq -c --arg f "$fid" '.[] | select((.id|tostring) == $f) | {description, visibility, options: [.options | sort_by(.priority)[] | {name, description}]}' <<<"$fields")"
    want="$(jq -c '.priority | {description, visibility, options: [.options[] | {name, description}]}' "$defs")"
    if [ "$now" = "$want" ]; then echo "  igual"; echo "Fixar o campo nos tipos é feito na interface (Settings → Issue fields → Pin), uma vez por conta."; return; fi
    # Keep the ids of the options that already exist, so issue values survive.
    opts="$(jq -c --argjson cur "$(jq -c --arg f "$fid" '.[] | select((.id|tostring) == $f) | .options' <<<"$fields")" \
      '[.priority.options[] | . as $o | {name, description} + ([$cur[] | select(.name == $o.name) | {id}] | first // {})]' "$defs")"
    run api -X PATCH "$base/issue-fields/$fid" --input - <<<"$(jq -c --argjson o "$opts" '.priority | {description, visibility, options: $o}' "$defs")"
    echo "  atualizado (opções na ordem de $defs)"
  fi
  echo "Fixar o campo nos tipos é feito na interface (Settings → Issue fields → Pin), uma vez por conta."
}

set_priority() { # repo number value [fid]
  local repo="$1" n="$2" v="$3" fid="${4:-}"
  jq -e --arg v "$v" '.priority.options | map(.name) | index($v)' "$defs" >/dev/null ||
    { echo "Prioridade inválida: $v (use $(jq -r '[.priority.options[].name] | join(", ")' "$defs"))" >&2; exit 2; }
  [ -n "$fid" ] || fid="$(field_id "$(base_for "${repo%%/*}")")"
  run api -X POST "repos/$repo/issues/$n/issue-field-values" --input - \
    <<<"$(jq -nc --argjson f "$fid" --arg v "$v" '{issue_field_values: [{field_id: $f, value: $v}]}')"
}

migrate() {
  local repo="${1:-$(default_repo)}" fid
  [ -n "$repo" ] || { echo "Informe owner/repo ou defina project.repo em $config" >&2; exit 2; }
  fid="$(field_id "$(base_for "${repo%%/*}")")"
  [ -n "$fid" ] || { echo "Campo Priority não existe: rode '$0 setup' antes." >&2; exit 1; }
  echo "Migração de labels em $repo$([ "$dry" -eq 1 ] && echo ' (dry-run)'):"
  local order='["Bug","Feature","Docs","Question","Task"]' prio='["Urgent","High","Medium","Low"]'
  api --paginate "repos/$repo/issues?state=all&per_page=100" \
    --jq '.[] | select(.pull_request | not) | {number, type: .type.name, labels: [.labels[].name]}' |
  while IFS= read -r i; do
    local n want_t want_p cur_t has_p
    n="$(jq -r .number <<<"$i")"; cur_t="$(jq -r '.type // empty' <<<"$i")"
    want_t="$(jq -r --slurpfile d "$defs" --argjson o "$order" \
      '[.labels[] | $d[0].fromLabels.type[.] // empty] | unique | (map(. as $t | $o | index($t)) | min) as $m | if $m then $o[$m] else empty end' <<<"$i")"
    want_p="$(jq -r --slurpfile d "$defs" --argjson o "$prio" \
      '[.labels[] | $d[0].fromLabels.priority[.] // empty] | (map(. as $t | $o | index($t)) | min) as $m | if $m then $o[$m] else empty end' <<<"$i")"
    [ -z "$want_t" ] && [ -z "$want_p" ] && continue
    if [ -n "$want_t" ] && [ -z "$cur_t" ]; then
      run api -X PATCH "repos/$repo/issues/$n" -f "type=$want_t"; echo "  #$n tipo $want_t"; pause
    fi
    if [ -n "$want_p" ]; then
      has_p="$(api "repos/$repo/issues/$n/issue-field-values" --jq "[.[] | select(.issue_field_id == $fid)] | length")"
      if [ "$has_p" = "0" ]; then set_priority "$repo" "$n" "$want_p" "$fid"; echo "  #$n prioridade $want_p"; pause; fi
    fi
  done
  echo "As labels continuam nas issues. '.standards/labels.sh --prune' apaga as que já foram migradas."
}

case "$cmd" in
  setup) setup "$@" ;;
  migrate) migrate "$@" ;;
  priority) [ $# -eq 3 ] || { echo "uso: $0 priority <owner/repo> <n> <valor>" >&2; exit 2; }; set_priority "$@" ;;
  *) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac

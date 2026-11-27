#!/usr/bin/env bash
# ============================================================================
# Branch protection on GitHub (CONTRIBUTING, "Fluxo de branches", "Commits").
# Creates or updates two rulesets:
#   main    — no deletion, no force-push, signed commits, changes only via PR
#   develop — no deletion, no force-push, signed commits (no PR rule: the
#             merge of main back into develop is a signed direct push)
# Also sets develop as the default branch, deletes branches on merge and
# turns off rebase merges. Rulesets on private repositories need GitHub Pro
# (or a paid organization plan); without it the script says so and stops.
# Usage: .standards/rulesets.sh [owner/repo]
# ============================================================================
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
repo="${1:-$(jq -r '.project.repo // empty' .standards.json)}"
[ -z "$repo" ] && { echo "Informe owner/repo ou defina project.repo em .standards.json" >&2; exit 2; }

echo "Configuração do repositório $repo:"
gh api -X PATCH "repos/$repo" -F delete_branch_on_merge=true -F allow_merge_commit=true \
  -F allow_squash_merge=true -F allow_rebase_merge=false -F allow_update_branch=true \
  -f merge_commit_title=PR_TITLE -f merge_commit_message=PR_BODY \
  -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY >/dev/null &&
  echo "  merge commit e squash com título e descrição do PR; rebase desligado; branch apagada no merge"
if gh api "repos/$repo/branches/develop" >/dev/null 2>&1; then
  gh api -X PATCH "repos/$repo" -f default_branch=develop >/dev/null && echo "  branch padrão: develop"
else
  echo "  (sem branch develop ainda: branch padrão inalterada)"
fi

ruleset() { # name branch include_pr
  local name="$1" branch="$2" pr="$3" body id
  body="$(jq -n --arg name "$name" --arg ref "refs/heads/$branch" --argjson pr "$pr" '{
    name: $name, target: "branch", enforcement: "active",
    conditions: { ref_name: { include: [$ref], exclude: [] } },
    rules: ([ {type: "deletion"}, {type: "non_fast_forward"}, {type: "required_signatures"} ]
      + (if $pr then [ { type: "pull_request", parameters: {
            required_approving_review_count: 0, dismiss_stale_reviews_on_push: false,
            require_code_owner_review: false, require_last_push_approval: false,
            required_review_thread_resolution: false } } ] else [] end))
  }')"
  id="$(gh api "repos/$repo/rulesets" --jq ".[] | select(.name == \"$name\") | .id" 2>/dev/null || true)"
  local out
  if [ -n "$id" ]; then
    out="$(printf '%s' "$body" | gh api -X PUT "repos/$repo/rulesets/$id" --input - 2>&1)" || { echo "$out" >&2; return 1; }
  else
    out="$(printf '%s' "$body" | gh api -X POST "repos/$repo/rulesets" --input - 2>&1)" || { echo "$out" >&2; return 1; }
  fi
  echo "  ruleset $name ($branch)"
}

# Rulesets on a private repository need GitHub Pro. Ask once, before touching
# anything: on a 403 the API answers with an error body, not a list.
if ! gh api "repos/$repo/rulesets" >/dev/null 2>&1; then
  echo "Rulesets indisponíveis em $repo: em repositório privado, eles exigem GitHub Pro." >&2
  echo "As travas do agente (.claude/hooks) continuam valendo; as do GitHub, não." >&2
  exit 1
fi

if ! ruleset "standards-main" main true; then
  echo "Não foi possível criar os rulesets. Em repositório privado, eles exigem GitHub Pro." >&2
  echo "As travas do agente (.claude/hooks) continuam valendo; as do GitHub, não." >&2
  exit 1
fi
ruleset "standards-develop" develop false

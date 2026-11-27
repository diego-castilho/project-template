#!/usr/bin/env bash
# ============================================================================
# Tests for .standards/check.sh — run: bash .standards/test-check.sh
# ============================================================================
# Subjects, branches and titles against a test config, offline. The cases
# are modeled on real commits of the projects that use this standard,
# plus the edges of each rule.
# ============================================================================
set -u
here="$(cd "$(dirname "$0")" && pwd)"
check="$here/check.sh"
fail=0; n=0

tmp="$(mktemp -d)"
trap 'command rm -rf "$tmp"' EXIT
printf '{"commitScopes": ["api", "ios", "changelog", "release", "deps", "deps-dev"]}\n' > "$tmp/standards.json"

expect() { # $1 pass|fail, then the check.sh arguments
  local want="$1"; shift
  n=$((n+1))
  if STANDARDS_CONFIG="$tmp/standards.json" bash "$check" "$@" >/dev/null 2>&1; then got=pass; else got=fail; fi
  if [ "$got" != "$want" ]; then
    fail=$((fail+1)); printf 'FAIL  expected %-4s got %-4s  %s\n' "$want" "$got" "$*"
  fi
}

# subjects that pass
expect pass subject 'feat(api): add the session clock'
expect pass subject 'fix(ios): keep the session after a revoked token'
expect pass subject 'docs: cite the issues opened for the review'
expect pass subject 'docs(changelog): the vite config build output (#314)'
expect pass subject 'chore(deps-dev): Bump zod from 4.3.6 to 4.6.7'
expect pass subject 'ci: check the documentation rules on every PR'
expect pass subject 'style(api): apply ruff format to the export parser'
expect pass subject 'style: apply the formatter'
expect pass subject 'chore(release): 1.23.4'
expect pass subject 'release: v1.23.4'
expect pass subject 'hotfix: v1.23.5'
expect pass subject 'feat(api)!: drop the legacy glucose fields'
expect pass subject 'Revert "feat(api): add the session clock"'
expect pass subject "docs: $(printf 'x%.0s' $(seq 1 90))"   # 96 chars: warns, passes

# subjects that fail
expect fail subject 'feat: fuso do usuário — relato do aparelho e utcOffset (#152)'   # feat without scope
expect fail subject 'fix: tipo da refeição obrigatório, como na web (#135)'
expect fail subject 'feat(kit): add the daily totals'                                 # scope not in the list
expect fail subject 'Plano do ciclo 1A e spec atualizado com o formato do export'      # not conventional
expect fail subject 'docs: add the roadmap.'                                           # trailing period
expect fail subject 'fixup! feat(api): add the session clock'
expect fail subject "docs: $(printf 'x%.0s' $(seq 1 100))"  # 106 chars

# branches
expect pass branch feat/12-oauth-login develop
expect pass branch fix/314-vite-config-output develop
expect pass branch chore/bump-1.23.4 develop
expect pass branch claude/cross-audit-gsxj2r develop
expect pass branch dependabot/npm_and_yarn/zod-4.6.7 develop
expect pass branch main develop
expect pass branch develop main
expect pass branch hotfix/1.4.1 main
expect fail branch feature/c1a-fundacao develop
expect fail branch fix/x main
expect fail branch hotfix/1.4.1 develop
expect fail branch feat/x feat/y

# titles
expect pass title 'release: v1.4.0' develop main
expect pass title 'hotfix: v1.4.1' hotfix/1.4.1 main
expect fail title 'Release 1.4.0' develop main
expect fail title 'hotfix: v1.4.0' hotfix/1.4.1 main
expect pass title 'feat(api): add the session clock' feat/x develop
expect fail title 'Add the session clock' feat/x develop

echo "check: $((n-fail))/$n ok"
[ "$fail" -eq 0 ]

#!/usr/bin/env bash
# ============================================================================
# Tests for .claude/hooks/guard-bash.sh — run: bash .standards/test-guard-bash.sh
# ============================================================================
# Each case feeds a command to the hook and checks the decision: allow (no
# output), ask or deny. A test config stands in for .standards.json, and the
# gh pr merge cases inject the PR's base and title so they run offline.
# ============================================================================
set -u
here="$(cd "$(dirname "$0")" && pwd)"
guard="$here/../.claude/hooks/guard-bash.sh"
fail=0; n=0

tmp="$(mktemp -d)"
trap 'command rm -rf "$tmp"' EXIT
cat > "$tmp/standards.json" <<'EOF'
{
  "production": { "paths": ["~/Docker"], "containers": ["app-backend", "postgres"] },
  "xrepo": { "enabled": true, "self": "app", "repos": ["owner/app-ios"] }
}
EOF

check() { # $1 expected (allow|ask|deny), $2 command, $3 optional "base<TAB>title" of the PR
  n=$((n+1))
  out="$(jq -cn --arg c "$2" '{tool_name:"Bash",tool_input:{command:$c}}' \
    | STANDARDS_CONFIG="$tmp/standards.json" STANDARDS_TEST_PR_INFO="${3:-}" PATH="$tmp:$PATH" bash "$guard")"
  got="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)"
  [ -z "$got" ] && got=allow
  if [ "$got" != "$1" ]; then
    fail=$((fail+1)); printf 'FAIL  expected %-5s got %-5s  %s\n' "$1" "$got" "$2"
  fi
}
TAB=$'\t'

# allow — everyday work
check allow 'git status'
check allow 'git push -u origin fix/236-dedup'
check allow 'git push origin develop'
check allow 'git push -u origin feat/main-menu'
check allow 'git log --oneline origin/main -5'
check allow 'git tag --sort=-creatordate | head'
check allow 'git tag -l "v1.*"'
check allow 'gh release list'
check allow 'gh release view v1.2.0'
check allow 'docker logs --since 5m app-backend'
check allow 'docker ps --format "{{.Names}}"'
check allow 'docker exec app-backend-dev node -p 1'
check allow 'docker compose -f docker-compose.dev.yml up -d app-backend-dev'
check allow 'command rm -f /tmp/claude-1000/scratchpad/a.md'
check allow 'rm -rf /private/tmp/wt'
check allow 'gh issue list -R owner/app-ios --label xrepo'
check allow 'gh issue create -R owner/app --title x --body-file /tmp/b.md'
check allow 'gh pr merge 1 --merge --delete-branch' "develop${TAB}feat(x): something"
check allow 'grep -n main CONTRIBUTING.md'
check allow 'echo "remain in place"'
check allow 'ls -la ~/Docker/*.archive'
check allow "grep -E '^KEY_' ~/Docker/.env 2>/dev/null | cut -d= -f1"
check allow 'git worktree list'
check allow 'git push --force-with-lease origin feat/x'

# deny — never
check deny 'git push origin main'
check deny 'git push origin HEAD:main'
check deny 'git push --force origin +main'
check deny 'cd x && git push origin main && echo ok'
check deny 'git push --force origin develop'
check deny 'gh pr merge 2 --merge' "main${TAB}chore(deps): bump foo"

# ask — the maintainer confirms
check ask 'gh pr merge 3 --squash --subject "release: v1.4.0"' "main${TAB}release: v1.4.0"
check ask 'gh pr merge 4 --squash --subject "hotfix: v1.4.1"' "main${TAB}hotfix: v1.4.1"
check ask 'gh pr merge 99 --merge'
check ask 'git tag -s v1.4.0 -m v1.4.0 origin/main'
check ask 'git tag -d v1.4.0'
check ask 'git push origin v1.4.0'
check ask 'git push --tags'
check ask 'gh release create v1.4.0 --verify-tag --latest'
check ask 'gh release edit v1.3.0 --notes-file n.md'
check ask 'cd ~/Docker && docker compose up -d --build app-backend'
check ask 'docker compose -f /Users/someone/Docker/docker-compose.yml restart postgres'
check ask 'docker restart app-backend'
check ask 'docker exec postgres psql -c "select 1"'
check ask 'command cp a.yml ~/Docker/docker-compose.yml'
check ask 'echo x > ~/Docker/.env'
check ask 'rm -f README.md'
check ask 'git push origin --delete fix/old'
check ask 'git branch -D fix/old'
check ask 'psql -c "DROP TABLE trades"'
check ask 'gh issue create -R owner/app-ios --title x --body-file /tmp/b.md'
check ask 'gh issue comment 12 -R owner/app-ios --body ok'

echo "guard-bash: $((n-fail))/$n ok"
[ "$fail" -eq 0 ]

#!/usr/bin/env bash
# ============================================================================
# dev-standards installer — new project, existing project or update
# ============================================================================
# Usage, from a dev-standards checkout (or from a project created from it):
#
#   .standards/install.sh --here  --name <Name> [--repo owner/repo]
#       Finalize a repository created with "Use this template": replace the
#       standard's own README, CHANGELOG and .standards.json with the
#       project's, and drop files that only make sense in dev-standards.
#
#   .standards/install.sh --into <dir> --name <Name> [--repo owner/repo]
#       Adopt the standard in an existing repository, or update one that
#       already follows it. Files owned by the standard are copied over;
#       managed blocks (<!-- standards:begin … --> … <!-- standards:end -->)
#       are replaced in place, leaving the project's part intact. Project
#       files are created only if missing; CLAUDE.md and .claude/settings.json
#       are merged. Nothing is committed: review with `git diff` in <dir>.
#       With --replace-hooks, the SessionStart hooks and the Bash PreToolUse
#       hooks already in .claude/settings.json are removed first (use it
#       when the project had its own guard hooks the standard replaces).
#
# Then, with gh logged in: .standards/issue-types.sh setup, .standards/labels.sh
# and .standards/rulesets.sh.
# ============================================================================
set -euo pipefail

src="$(cd "$(dirname "$0")/.." && pwd)"
version="$(tr -d '[:space:]' < "$src/.standards/VERSION")"
mode=""; dest=""; name=""; repo=""; replace_hooks=0
while [ $# -gt 0 ]; do
  case "$1" in
    --here) mode=here; dest="$src"; shift ;;
    --into) mode=into; dest="$(cd "${2:?--into <dir>}" && pwd)"; shift 2 ;;
    --name) name="${2:?}"; shift 2 ;;
    --repo) repo="${2:?}"; shift 2 ;;
    --replace-hooks) replace_hooks=1; shift ;;
    *) sed -n '2,27p' "$0"; exit 2 ;;
  esac
done
[ -z "$mode" ] && { sed -n '2,27p' "$0"; exit 2; }
if [ -z "$repo" ]; then
  url="$(git -C "$dest" remote get-url origin 2>/dev/null || true)"
  repo="$(printf '%s' "$url" | sed -nE 's#.*github\.com[:/]([^/]+/[^/.]+)(\.git)?$#\1#p')"
fi
[ -z "$name" ] && name="$(basename "$dest")"
slug="$(printf '%s' "${repo##*/}" | tr '[:upper:]' '[:lower:]')"; [ -z "$slug" ] && slug="$(printf '%s' "$name" | tr '[:upper:] ' '[:lower:]-')"

say() { printf '  %s\n' "$*"; }
subst() { sed -e "s#__PROJECT_NAME__#${name}#g" -e "s#__PROJECT_REPO__#${repo}#g" \
              -e "s#__PROJECT_SLUG__#${slug}#g" -e "s#__STANDARDS_VERSION__#${version}#g"; }

# Files the standard owns: always replaced (or block-replaced when they have markers).
OWNED=(
  CONTRIBUTING.md CONTRIBUTING.pt-BR.md
  .claude/hooks/guard-bash.sh .claude/hooks/session-start.sh
  .github/pull_request_template.md
  .github/ISSUE_TEMPLATE/bug.yml .github/ISSUE_TEMPLATE/feature.yml
  .github/ISSUE_TEMPLATE/task.yml .github/ISSUE_TEMPLATE/docs.yml
  .github/ISSUE_TEMPLATE/question.yml .github/ISSUE_TEMPLATE/config.yml
  .standards/VERSION .standards/check.sh .standards/install.sh .standards/labels.sh
  .standards/labels.json .standards/issue-types.sh .standards/issue-types.json .standards/rulesets.sh .standards/test-guard-bash.sh .standards/test-check.sh
  .standards/templates/CHANGELOG.md .standards/templates/README.md
  .standards/templates/README.pt-BR.md .standards/templates/standards.json
  .standards/templates/standards.yml
  docs/adr/0000-template.md docs/REGRAS.md
)
# Files seeded once, then owned by the project. The xrepo template is the
# project's because each repository fills in who sends it requests.
SEEDED=( .github/workflows/ci.yml .github/dependabot.yml docs/adr/README.md .github/ISSUE_TEMPLATE/xrepo-request.md )

# Replace every managed block of $2 (target) with the same-named block of $1.
replace_blocks() { # src target
  awk -v SRC="$1" '
    BEGIN {
      while ((getline line < SRC) > 0) {
        if (line ~ /<!-- standards:begin /) { split(line, p, " "); cur = p[3]; blk[cur] = line }
        else if (cur != "") { blk[cur] = blk[cur] "\n" line; if (line ~ /<!-- standards:end -->/) cur = "" }
      }
    }
    /<!-- standards:begin / { split($0, p, " "); n = p[3]; if (n in blk) { print blk[n]; skip = 1; next } }
    skip && /<!-- standards:end -->/ { skip = 0; next }
    !skip { print }
  ' "$2" > "$2.tmp" && mv "$2.tmp" "$2"
}
has_blocks() { case "$1" in *.md) grep -q '^<!-- standards:begin ' "$1" 2>/dev/null ;; *) return 1 ;; esac; }

copy_owned() { # relative path
  local f="$1" s="$src/$1" d="$dest/$1"
  [ "$s" = "$d" ] && return 0
  mkdir -p "$(dirname "$d")"
  if [ -f "$d" ] && has_blocks "$s" && has_blocks "$d"; then
    cp "$d" "$d.before"; replace_blocks "$s" "$d"
    cmp -s "$d" "$d.before" || say "blocos atualizados: $f"; rm -f "$d.before"
  elif [ -f "$d" ] && has_blocks "$s" && ! cmp -s "$s" "$d"; then
    cp "$d" "$d.pre-standards"; cp "$s" "$d"
    say "substituído: $f (o anterior ficou em $f.pre-standards: leve o que for do projeto para a seção do projeto)"
  elif ! cmp -s "$s" "$d" 2>/dev/null; then
    cp "$s" "$d"; say "copiado: $f"
  fi
  case "$f" in *.sh) chmod +x "$d" ;; esac
}

seed() { # relative path, content on stdin
  local d="$dest/$1"
  if [ -f "$d" ]; then cat >/dev/null; say "mantido (é do projeto): $1"; return; fi
  mkdir -p "$(dirname "$d")"; cat > "$d"; say "criado: $1"
}

merge_claude_md() {
  local d="$dest/CLAUDE.md" s="$src/CLAUDE.md" tmp
  if [ -f "$d" ] && has_blocks "$d"; then replace_blocks "$s" "$d"; say "blocos atualizados: CLAUDE.md"; return; fi
  tmp="$(mktemp)"
  if [ -f "$d" ]; then
    # Keep the project's title; the rest of the old file becomes the project section,
    # one heading level down.
    title="$(grep -m1 -E '^# ' "$d" || echo "# ${name}")"
    {
      printf '%s\n\n' "$title"
      awk '/<!-- standards:begin agent/,/<!-- standards:end -->/' "$s"
      printf '\n## Específico deste projeto\n\n'
      awk 'NR == 1 && /^# / { next } !started && /^[[:space:]]*$/ { next } { started = 1; print }' "$d" \
        | sed -E 's/^(#{2,5}) /#\1 /'
    } > "$tmp"
    cp "$d" "$d.pre-standards"
    say "mesclado: CLAUDE.md (o conteúdo anterior foi para \"Específico deste projeto\"; cópia em CLAUDE.md.pre-standards)"
  else
    sed "s#^\# <Nome do projeto>#\# ${name}#" "$s" > "$tmp"; say "criado: CLAUDE.md"
  fi
  mv "$tmp" "$d"
}

merge_settings() {
  local d="$dest/.claude/settings.json" s="$src/.claude/settings.json" tmp
  mkdir -p "$dest/.claude"
  if [ ! -f "$d" ]; then cp "$s" "$d"; say "criado: .claude/settings.json"; return; fi
  [ "$s" = "$d" ] && return 0
  tmp="$(mktemp)"
  if [ "$replace_hooks" -eq 1 ]; then
    jq '(.hooks.SessionStart // empty) |= [] | (.hooks.PreToolUse // empty) |= map(select(.matcher != "Bash"))' "$d" > "$tmp" && mv "$tmp" "$d"
    say "hooks SessionStart e PreToolUse (Bash) anteriores removidos (--replace-hooks)"
  else
    other="$(jq -r '[.hooks.SessionStart[]?.hooks[]?.command, (.hooks.PreToolUse[]? | select(.matcher == "Bash") | .hooks[]?.command)] | map(select(test("\\.claude/hooks/(guard-bash|session-start)\\.sh") | not)) | .[]' "$d" 2>/dev/null)"
    if [ -n "$other" ]; then
      say "atenção: .claude/settings.json já tem hooks que não são do padrão e vão rodar junto:"
      printf '%s\n' "$other" | sed 's/^/      /'
      say "se eles fazem o mesmo papel, rode de novo com --replace-hooks"
    fi
  fi
  # Add each standard hook entry unless a hook with the same command is already there.
  jq --slurpfile std "$s" '
    reduce ($std[0].hooks | to_entries[]) as $ev (.;
      reduce $ev.value[] as $entry (.;
        if ([.hooks[$ev.key][]?.hooks[]?.command] | index($entry.hooks[0].command)) then .
        else .hooks[$ev.key] = ((.hooks[$ev.key] // []) + [$entry]) end))
  ' "$d" > "$tmp" && mv "$tmp" "$d"
  say "mesclado: .claude/settings.json (hooks do padrão acrescentados, o resto mantido)"
}

# Skills arrive through gh skill, pinned to this version's tag, so that
# `gh skill update` and `gh skill list` know where they came from. Without gh
# skill, or before the tag exists, they are copied as before.
SKILLS=(release hotfix xrepo)
# Where the skills come from: always the standard's own repository, never the
# project's (in a repository made from project-template, .standards.json names
# the project).
standards_repo="${STANDARDS_REPO:-diego-castilho/dev-standards}"
install_skills() {
  local s
  for s in "${SKILLS[@]}"; do
    if command -v gh >/dev/null 2>&1 && gh skill --help >/dev/null 2>&1 &&
       (cd "$dest" && gh skill install "$standards_repo" ".claude/skills/$s/SKILL.md" --pin "v${version}" \
          --agent claude-code --scope project --allow-hidden-dirs --force >/dev/null 2>&1); then
      say "skill: $s (gh skill, v${version})"
    else
      copy_owned ".claude/skills/$s/SKILL.md"
      say "skill: $s copiada (gh skill indisponível ou tag v${version} ainda não publicada)"
    fi
  done
}

echo "dev-standards ${version} → ${dest} (${name}${repo:+, ${repo}})"

if [ "$mode" = into ]; then
  for f in "${OWNED[@]}"; do copy_owned "$f"; done
  install_skills
  for f in "${SEEDED[@]}"; do seed "$f" < "$src/$f"; done
  merge_claude_md
  merge_settings
else
  # --here: the repository came from the template; turn it into the project.
  for f in README.md README.pt-BR.md CHANGELOG.md; do
    subst < "$src/.standards/templates/$f" > "$dest/$f"; say "projeto: $f"
  done
  rm -f "$dest/.standards.json" "$dest/.standards/verify.sh" "$dest/.github/workflows/actions.lock"
  rm -rf "$dest/check"
  install_skills
  sed -i.bak "s#^\# <Nome do projeto>#\# ${name}#" "$dest/CLAUDE.md" && rm -f "$dest/CLAUDE.md.bak"
fi

# The standards workflow points at the check action of this version.
mkdir -p "$dest/.github/workflows"
subst < "$src/.standards/templates/standards.yml" > "$dest/.github/workflows/standards.yml"
say "gerado: .github/workflows/standards.yml (dev-standards/check@v${version})"

subst < "$src/.standards/templates/standards.json" | seed .standards.json
if [ -f "$dest/.standards.json" ]; then
  tmp="$(mktemp)"; jq --arg v "$version" '.standardsVersion = $v' "$dest/.standards.json" > "$tmp" && mv "$tmp" "$dest/.standards.json"
  say "standardsVersion = ${version}"
fi
subst < "$src/.standards/templates/CHANGELOG.md" | seed CHANGELOG.md
if [ ! -f "$dest/README.md" ] && [ ! -f "$dest/README.pt-BR.md" ]; then
  subst < "$src/.standards/templates/README.md" | seed README.md
  subst < "$src/.standards/templates/README.pt-BR.md" | seed README.pt-BR.md
elif [ ! -f "$dest/README.md" ] || [ ! -f "$dest/README.pt-BR.md" ]; then
  say "atenção: README.md e README.pt-BR.md precisam existir juntos (check bilingual)"
fi

cat <<EOF

Próximos passos:
  1. Revise: git -C "$dest" status && git -C "$dest" diff
  2. Ajuste .standards.json: commitScopes, verify, release, production, xrepo.
  3. Leve o que era do projeto dos arquivos *.pre-standards para a seção do projeto e apague-os.
  4. Lockfile das Actions: gh actions-lock (extensão github/gh-actions-lock), e commite o resultado.
     Se o repositório restringe as Actions permitidas, libere diego-castilho/dev-standards/check@*.
  5. Commit: chore(standards): adopt dev-standards ${version}
  6. Com o gh: .standards/issue-types.sh setup, .standards/labels.sh --prune  e  .standards/rulesets.sh
EOF

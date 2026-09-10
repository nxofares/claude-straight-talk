#!/usr/bin/env bash
# Test suite for the straight-talk plugin.
#
# A plugin that legislates about evidence-backed claims has to be able to back
# its own. Run with: ./tests/run-tests.sh

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="${ROOT}/hooks/session-start"
pass=0
fail=0

ok()   { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
nope() { printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; fail=$((fail + 1)); }

json_valid() {
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null
    elif command -v jq >/dev/null 2>&1; then
        jq -e . >/dev/null 2>&1
    else
        echo "no python3 or jq available for JSON validation" >&2
        return 2
    fi
}

echo "structural"

for f in .claude-plugin/plugin.json hooks/hooks.json hooks/contract.md \
         hooks/session-start skills/straight-talk/SKILL.md \
         skills/straight-talk/references/examples.md README.md LICENSE; do
    [ -f "${ROOT}/${f}" ] && ok "exists: ${f}" || nope "missing: ${f}"
done

for f in .claude-plugin/plugin.json hooks/hooks.json; do
    json_valid < "${ROOT}/${f}" && ok "parses: ${f}" || nope "invalid JSON: ${f}"
done

[ -x "$HOOK" ] && ok "hook is executable" || nope "hook is not executable"

head -1 "${ROOT}/skills/straight-talk/SKILL.md" | grep -q '^---$' \
    && ok "SKILL.md has frontmatter" || nope "SKILL.md missing frontmatter"

for key in name description; do
    grep -qE "^${key}: .+" "${ROOT}/skills/straight-talk/SKILL.md" \
        && ok "frontmatter has ${key}" || nope "frontmatter missing ${key}"
done

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "$HOOK" "${ROOT}/tests/run-tests.sh" >/dev/null 2>&1 \
        && ok "shellcheck clean" || nope "shellcheck reported issues"
else
    echo "  skip shellcheck (not installed)"
fi

echo
echo "behavioural: one context field per host"

# Claude Code
out=$(CLAUDE_PLUGIN_ROOT="$ROOT" COPILOT_CLI= CURSOR_PLUGIN_ROOT= "$HOOK" 2>/dev/null)
printf '%s' "$out" | json_valid && ok "claude code: valid JSON" || nope "claude code: invalid JSON"
printf '%s' "$out" | grep -q 'hookSpecificOutput' \
    && ok "claude code: uses hookSpecificOutput" || nope "claude code: wrong field"
[ "$(printf '%s' "$out" | grep -c 'additional_context')" -eq 0 ] \
    && ok "claude code: no duplicate snake_case field" \
    || nope "claude code: emitted two fields, context would inject twice"

# Cursor
out=$(CURSOR_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_ROOT="$ROOT" "$HOOK" 2>/dev/null)
printf '%s' "$out" | json_valid && ok "cursor: valid JSON" || nope "cursor: invalid JSON"
printf '%s' "$out" | grep -q 'additional_context' \
    && ok "cursor: uses additional_context" || nope "cursor: wrong field"
[ "$(printf '%s' "$out" | grep -c 'hookSpecificOutput')" -eq 0 ] \
    && ok "cursor: no nested field" || nope "cursor: emitted two fields"

# Copilot CLI
out=$(COPILOT_CLI=1 CLAUDE_PLUGIN_ROOT="$ROOT" CURSOR_PLUGIN_ROOT= "$HOOK" 2>/dev/null)
printf '%s' "$out" | json_valid && ok "copilot: valid JSON" || nope "copilot: invalid JSON"
printf '%s' "$out" | grep -q '"additionalContext"' \
    && ok "copilot: uses additionalContext" || nope "copilot: wrong field"

echo
echo "behavioural: contract content"

out=$(CLAUDE_PLUGIN_ROOT="$ROOT" "$HOOK" 2>/dev/null)
for law in "ANSWER FIRST" "CLAIMS CARRY EVIDENCE" "ASSUMPTIONS SURFACE INLINE" \
           "REPORT DECISIONS, NOT STEPS"; do
    printf '%s' "$out" | grep -q "$law" && ok "law present: ${law}" || nope "law missing: ${law}"
done

# A missing contract must fail loudly, not inject an empty contract silently.
tmp=$(mktemp -d)
cp "$HOOK" "${tmp}/session-start"
if CLAUDE_PLUGIN_ROOT="$ROOT" "${tmp}/session-start" >/dev/null 2>&1; then
    nope "missing contract.md exits 0" "should fail loudly rather than inject nothing"
else
    ok "missing contract.md fails loudly"
fi
rm -rf "$tmp"

echo
echo "drift: contract quoted in SKILL.md matches hooks/contract.md"

# The four law headings are the contract's load-bearing text. If the hook and
# the skill disagree about them, users get two different rule sets.
drift=0
while IFS= read -r law; do
    grep -q "$law" "${ROOT}/skills/straight-talk/SKILL.md" || { drift=1; echo "       drifted: ${law}"; }
done <<LAWS
Answer first
Claims carry evidence
Assumptions surface inline
Report decisions, not steps
LAWS
[ "$drift" -eq 0 ] && ok "no drift between contract and SKILL.md" || nope "contract and SKILL.md disagree"

echo
echo "self-compliance"

words=$(wc -w < "${ROOT}/hooks/contract.md")
[ "$words" -le 200 ] \
    && ok "contract is ${words} words (cap 200)" \
    || nope "contract is ${words} words" "a rule against walls of text, delivered as one"

for f in hooks/contract.md skills/straight-talk/SKILL.md; do
    grep -qi 'TODO\|TBD\|FIXME' "${ROOT}/${f}" \
        && nope "${f} contains a placeholder" || ok "no placeholders: ${f}"
done

grep -q '^## Exceptions' "${ROOT}/skills/straight-talk/SKILL.md" \
    && ok "Exceptions section present" || nope "Exceptions section missing"

echo
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

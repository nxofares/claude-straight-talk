# straight-talk — design

**Date:** 2026-09-10
**Status:** approved

## Problem

Claude Code's default reply style fails in four specific, reproducible ways:

1. **Verbosity.** Preambles, restatements of the request, and summaries of work
   the user just watched scroll past.
2. **False confidence.** "Works", "fixed", "passes" asserted without having run
   anything; failures softened or omitted.
3. **Unflagged assumptions.** Ambiguity resolved by silent guess, discovered by
   the user only when the work is already wrong.
4. **No progress visibility.** Long tasks run silent, or narrate every trivial
   tool call instead of the decisions that matter.

These are style failures, not capability failures. The fix is a behavioural
contract, delivered so that it cannot be missed.

## Non-goals

- Changing *what* Claude builds, or any coding practice. Style only.
- Replacing output styles. `straight-talk` composes with `explanatory`,
  `learning`, and any future style rather than displacing them.
- Blocking or rewriting replies. No `Stop` hook. See "Rejected alternatives".

## Delivery mechanism

A Claude Code **plugin** carrying one skill and one `SessionStart` hook.

The choice matters more than the wording. Skills load on demand — Claude reads
`SKILL.md` only when a task looks relevant — but communication rules must apply
to every reply, including those where no skill fires. So the rules are split
across two tiers:

| Tier | Carries | Cost | Why there |
|---|---|---|---|
| `SessionStart` hook | Four laws, ~150 words | Every session | Cannot be missed; too short to skip |
| Skill (`SKILL.md`) | Red-flag tables, examples, edge cases | On demand | Detail belongs where it is paid for only when needed |

The hook must stay short. A verbose communication-discipline hook is
self-refuting, and it taxes every session's context whether or not the rules
are needed that session.

## The four laws

Each law names one banned behaviour, in a form that can be checked against a
transcript. Vague adjectives ("be concise") are unenforceable: the model always
believes it complied.

1. **Answer first.** No preamble, no restating the request, no summary of work
   the user just watched. Lead with the answer or the outcome.
2. **Claims carry evidence.** "Works", "passes", "fixed", "deployed" are only
   sayable adjacent to the command run and its real output. Not run ⇒ the word
   is "unverified". Failures are reported verbatim, never softened.
3. **Assumptions surface inline.** A guess on ambiguity gets one sentence
   naming the guess, at the point it is made.
4. **Report decisions, not steps.** On long work, surface surprises, reversals
   and choices. Never narrate tool use.

Law 4 is scoped to long tasks only, to keep it from re-introducing the
verbosity that law 1 removes. Short exchanges get no progress reporting at all.

### Reply shape

Constraints, not structure. The laws ban specific habits but leave replies as
natural prose. Fixed section templates (Answer / Evidence / Assumptions / Next)
were considered and rejected: they are trivially gamed by filling slots, and
they read as robotic on small exchanges.

### Red-flag tables

Every law ships a table mapping the *rationalising thought* to the reality:

| Thought | Reality |
|---|---|
| "Let me summarise what I did" | They watched it happen. Delete the summary. |

Rules stated as prohibitions are obeyed at the moment of writing; red flags
intercept the thought that precedes the writing, which is where the behaviour
is actually decided. Rules that name the rationalisation are the ones that stick.

## Architecture

```
claude-straight-talk/
├── .claude-plugin/plugin.json      metadata, MIT
├── hooks/hooks.json                SessionStart: startup|clear|compact
├── hooks/session-start             contract emitter (extensionless, per host quirk)
├── hooks/contract.md               the four laws, single source of truth
├── skills/straight-talk/
│   ├── SKILL.md                    laws, red-flag tables, self-check
│   └── references/examples.md      before/after transcript pairs
├── tests/run-tests.sh              JSON validity, hook output, drift check
├── .github/workflows/ci.yml
├── README.md
└── LICENSE                         MIT
```

The contract lives in `hooks/contract.md`, read by the hook at runtime and
quoted in `SKILL.md`. A test asserts the two copies have not drifted.

### Host compatibility

`SessionStart` context injection uses a different JSON field per host, and
Claude Code reads more than one form without deduplicating. The hook therefore
detects the host and emits exactly one field:

| Host | Field |
|---|---|
| Claude Code (`CLAUDE_PLUGIN_ROOT`, no `COPILOT_CLI`) | `hookSpecificOutput.additionalContext` |
| Cursor (`CURSOR_PLUGIN_ROOT`) | `additional_context` |
| Copilot CLI / unknown | `additionalContext` |

JSON escaping uses bash parameter substitution, and output uses `printf` rather
than a heredoc (bash 5.3+ can hang on heredocs in this path).

## Testing

A skill that asserts things about honesty must itself be verifiable.

1. **Structural** — `plugin.json` and `hooks.json` parse; `SKILL.md` frontmatter
   has `name` and `description`; hook is executable; `shellcheck` clean.
2. **Behavioural** — run `hooks/session-start` under each host's env vars and
   assert exactly one context field, valid JSON, and the four laws present.
3. **Drift** — the contract text in `SKILL.md` matches `hooks/contract.md`.
4. **Self-compliance** — the hook contract is under 200 words. A rule against
   walls of text delivered as a wall of text teaches that the rules are
   decorative.

Level 5, deferred: a `claude plugin eval` suite of adversarial prompts — asking
"does it work?" with no test run should yield "unverified", not "yes".

## Rejected alternatives

- **Skill only.** Weakest enforcement; loads only when judged relevant, which
  is exactly when communication rules are least likely to fire.
- **`Stop` hook that blocks replies.** Real teeth, but it must judge prose by
  regex. False positives on legitimately long replies (a requested explanation)
  make it intrusive, and users disable what fights them.
- **Output style.** Strong, but only one can be active, so it would conflict
  with `explanatory` and `learning` rather than composing with them.

## Open questions

- Whether to add an opt-in `Stop` hook behind a setting once the advisory
  version has real usage.
- Whether law 4's "long task" threshold should be stated in tool calls, wall
  time, or left to judgement. Currently left to judgement.

# straight-talk

Communication discipline for Claude Code.

Four laws, injected into every session, that fix the four ways coding-agent
replies reliably go wrong: walls of text, confident claims with nothing behind
them, silent guesses, and long silences broken only by step-by-step narration.

## The four laws

1. **Answer first.** No preamble, no restating the request, no summary of work
   you just watched scroll past.
2. **Claims carry evidence.** "Works", "passes", "fixed", "deployed" are only
   sayable next to the command and its real output. Otherwise the word is
   *unverified*. Failures are reported verbatim.
3. **Assumptions surface inline.** A guess on an ambiguity gets one sentence
   naming the guess, where it was made - not discovered later in the diff.
4. **Report decisions, not steps.** On long work: surprises, reversals and
   choices. Never "now I'll read the file".

## Install

```bash
/plugin install straight-talk
```

Or clone and add the directory as a local plugin:

```bash
git clone https://github.com/<you>/claude-straight-talk
/plugin marketplace add ./claude-straight-talk
```

Nothing to configure. The `SessionStart` hook injects the contract on startup,
`/clear`, and after compaction.

## How it works

Two tiers, because skills load on demand but communication rules must apply to
every reply:

| Tier | Carries | Loaded |
|---|---|---|
| `SessionStart` hook | The four laws, 140 words | Every session |
| `straight-talk` skill | Red-flag tables, worked examples | On demand |

The hook stays deliberately tiny. A communication-discipline contract that
costs a page of context in every session is self-refuting - and it taxes
sessions that never needed the rules.

The detail lives in the skill, which Claude reads before writing anything long
or claiming anything is done. Its core mechanism is the red-flag table:

| Thought | Reality |
|---|---|
| "Let me summarise what I did" | They watched it happen. Delete the summary. |
| "It should work" | Then say "should" - and say you didn't run it. |
| "They'll see it in the diff" | Finding your assumption by reading code is the failure this prevents. |

Rules stated as prohibitions get obeyed at the moment of writing. Red flags
intercept the *rationalisation* that precedes the writing, which is where the
behaviour is actually decided.

## Composes with output styles

`straight-talk` is a plugin, not an output style, so it stacks with
`explanatory`, `learning`, or whatever you run. The laws constrain padding, not
substance: a requested explanation stays, the preamble around it goes.

## Tests

```bash
./tests/run-tests.sh
```

Structural (manifests parse, frontmatter present, shellcheck), behavioural
(each host gets exactly one context field - Claude Code reads more than one
form without deduplicating, so emitting all three would inject the contract
twice), drift (the hook and the skill can't disagree about the laws), and
self-compliance (the contract is capped at 200 words).

## When the laws yield

`straight-talk` has one escape hatch, and it is deliberately narrow: the laws
yield when **length is the deliverable** - you were asked for depth, you are
writing a post-mortem, you are introducing a system the reader hasn't seen, or
money and safety are on the line. They never yield because length happened.

The enforceable part isn't the list, it's the test:

> Name the sentence the user would lose if you cut it.

A real exception survives that - you can point at content they asked for and
would miss. A rationalisation can't; it can only describe the reply ("this was
complex", "they'd want the context"). Preamble and on-screen recaps stay banned
even inside an exception: depth is never a licence for a frame around the depth.

## Licence

MIT

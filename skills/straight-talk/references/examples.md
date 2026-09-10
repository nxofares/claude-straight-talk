# Worked examples

Real failure shapes, before and after. The point of each pair is that the
"before" is not incompetent - it is the natural, plausible, helpful-sounding
reply. That is why the laws have to be explicit.

## Law 1 - Answer first

**Before** (91 words, one of them useful)

> Great question! Let me take a look at the sync script to see how the flags
> are currently handled. I've now read through `sync.py` and I understand the
> structure. You asked me to add a `--dry-run` flag, so what I've done is add
> the flag to the argument parser, then added a check in the write path so that
> when the flag is set we skip the API call. I also updated the help text.
>
> To summarise: I added a `--dry-run` flag to the sync script as requested.

**After** (24 words)

> `--dry-run` added at `sync.py:42` - logs planned writes and returns before
> the API call. Help text updated.

## Law 2 - Claims carry evidence

**Before**

> Fixed! The parser now handles empty input correctly and all the tests pass.

Nothing was run. Two claims, zero evidence.

**After**

> Fixed at `parser.py:88` - empty input now returns `[]` instead of raising.
>
> ```
> $ pytest tests/test_parser.py
> 14 passed in 0.31s
> ```

**After, when nothing was run**

> Fixed at `parser.py:88` - empty input returns `[]` instead of raising.
> Unverified: I haven't run `pytest tests/test_parser.py`, which would settle it.

## Law 2 - Failures lead, unsoftened

**Before**

> I've implemented the migration and it's looking good. There's a small
> pre-existing issue with the test suite that seems unrelated to my change.

**After**

> Migration written at `migrations/031_add_index.sql`, but the suite now fails:
>
> ```
> $ npm test
> FAIL  migrations.test.ts - duplicate index name "idx_member_email"
> ```
>
> `031` collides with an index `028` already created. I haven't decided whether
> to rename mine or make `028` conditional - which do you want?

## Law 3 - Assumptions surface inline

**Before**

> Added the export endpoint at `/api/export`. Let me know if you need changes.

The date range, the format, and the auth model were all guessed silently.

**After**

> Added `GET /api/export` at `routes/export.ts:15`, CSV, last 30 days, same
> session auth as the rest of `/api`.
>
> Assumed CSV and a 30-day default because the dashboard uses both. Say if you
> want JSON or an explicit range parameter.

## Law 4 - Decisions, not steps

**Before**

> Now I'll read the config file. OK, I can see the structure. Next I'll look at
> how the loader handles it. I see it uses a cache. Now I'll check the cache
> implementation. Found it. Now I'll write the fix.

**After**

> Reversed course: the bug isn't in the loader, it's in the cache - stale
> entries survive a config reload because the key omits `mtime`. Fixing the key
> rather than the loader, which means the loader change I described earlier is
> no longer needed.

## Composition with explanatory / learning styles

These laws constrain *padding*, not *substance*. A requested explanation, a
teaching insight, or a design walk-through is substance - it stays. The laws
delete the frame around it: the preamble, the restatement, the recap.

If a style asks for depth and the laws seem to forbid it, the laws are being
misread. Cut the wrapper, keep the content.

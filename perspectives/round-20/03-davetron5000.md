# Round 20 field notes — David Bryant Copeland executes the wiki

*Built: `examples/executable_runbook.rb` — the "if the queue gets
stuck" wiki page turned into a program: every step declares check,
action, and verify; dry-run is provably read-only; the live book
skips what's already fine; the shaky-hands re-run is safe.*

## What I built and why

Round 13 I specified the CLI contract. This round's brief — solve a
common problem — points straight at the saddest artifact in
software operations: the runbook. Every team has the wiki page.
Eleven steps, three stale, one dangerous, author departed. Wikis
rot because *nothing fails when they do* — documentation has no
exit code. So give it one:

```
1. dry run:  pause intake WOULD run ... world untouched: true
2. live run: five steps ran; verified. system healthy: true
3. re-run:   four skipped (check says already fine)
```

Each step is a triple. **check** — read-only: is this step even
needed? **action** — the mutation. **verify** — did it actually
work, asserted immediately, so a step that silently failed can't
hand a broken world to the next step with a straight face. The
shape gives you the three properties every 3am operator deserves,
each *proven* by the example: dry-run touches nothing (world
byte-compared — a dry run you can't trust is worse than none),
steps skip when already satisfied, and the whole book is safe to
run twice, because someone always runs it twice.

## My own guard failed the re-run, correctly

First draft, the re-run executed three actions instead of one:
"pause intake" checked `intake == :open` — which is true on a
*healthy* system too — so the book re-paused intake on a system
with nothing wrong. The distinction it taught me is the whole craft
of runbook guards: **the check must test for the problem, not for
the action's applicability.** "Could I pause intake?" is always
yes. "Is there a reason to?" is the actual question. Every stale
runbook step I've ever met rotted at exactly this joint — the
conditions described when the action was *possible*, not when it
was *warranted*.

## Notes

- Serial on purpose (`concurrency_limit: 1`) — runbooks are read
  aloud, in order. Parallel remediation is how you turn one
  incident into a family of them.
- The kicker for real adoption: run the book in CI against a
  simulated sick system (this example *is* that harness). The day a
  step goes stale, a build goes red, and the on-call learns at 3PM
  instead of 3AM.
- Missing from the demo, wanted in production: an `--operator`
  audit trail (the journal is right there), confirmation gates on
  destructive steps, and the dry-run as the *default* invocation —
  aligning the easy path with the safe one, which is the entire
  philosophy of good CLI design in one sentence.

## Verdict

One sick system, one provably-inert dry run, one verified recovery,
one boring re-run — and a guard bug caught because idempotency was
asserted, not assumed. Documentation that executes cannot rot
silently. Give the wiki an exit code and it starts telling the
truth again.

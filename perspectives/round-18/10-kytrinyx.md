# Round 18 field notes — Katrina Owen builds the étude machine

*Built: `examples/etude_machine.rb` — deliberate practice for
plan-builders: three graded études (broken plan + hint + hidden
test), with the machine holding itself to the practice-room
standard: broken forms must fail, model solutions must pass,
difficulty must climb one concept at a time.*

## What I built and why

Round 11 I wrote katas. Asked for creativity this time, I built the
thing exercism taught me matters more than any single exercise: the
**quality bar for exercises themselves.** Everyone who has ever
made a practice problem has shipped at least one of the two classic
failures — the exercise that passes before you touch it (false
confidence, zero learning), and the exercise that can't be solved
at all (that's not rigor, that's hazing). Both failures are
*testable*, so the machine tests for them:

```
1. The Missing Thread    broken fails: yes    solution passes: yes
2. The Swapped Hats      broken fails: yes    solution passes: yes
3. The Stubborn Courier  broken fails: yes    solution passes: yes
curriculum: 1 -> 2 -> 3 concepts per etude - each adds exactly one
```

Each étude is a tiny broken plan with a hint and a hidden test. The
Missing Thread is a dependency that was never wired (`greet` reads
`previous_output` from nobody); The Swapped Hats has two agents
wearing each other's job descriptions; The Stubborn Courier fails
transiently while the plan gives up permanently — one retry-policy
line fixes it. Before any student sees them, the machine runs every
étude both ways: the broken form *must* fail the hidden test, and
the bundled model solution *must* pass it. Self-verifying
curriculum. Exercises rot exactly like docs do, and the cure is the
same: run them in CI.

## One reach away

The difficulty gradient is the part I care most about, and it's
*measured*, not asserted: étude N's solution touches exactly N
concepts — dependencies, then agents, then retry policy — and the
referee checks monotonicity. Practice is only deliberate when the
next rung is one reach away; a curriculum that jumps two rungs
isn't harder, it's just noisier feedback. And feedback speed is the
other half of the pedagogy: a hidden test with an exit code answers
in seconds. The alternative — finding out in code review three
weeks later — is technically also feedback, in the way that a
postcard from a moved-away friend is technically also conversation.

## Notes

- The hints are calibrated to name the *neighborhood*, not the fix:
  "greet reads previous_output... from whom?" A hint that names the
  fix steals the rep; a hint that names nothing is a shrug.
- The build lambda taking `:broken | :solved` keeps each étude's
  defect and its repair adjacent in the source — the diff between
  modes IS the lesson, readable in one glance.
- Obvious growth: student mode (present broken form, accept a
  patch, run the hidden test), a fourth étude on `needs:` naming,
  and per-étude journals so a mentor can watch the attempt, not
  just the outcome. The exercism instinct: the attempt is where the
  teaching lives.

## Verdict

Three études, six verification runs, one monotonic curriculum, no
free passes and no hazing. The framework made exercises cheap to
express (a broken plan is just a plan with one thing missing), and
the machine made them trustworthy — which is the whole trick of
teaching with software: the curriculum has to pass its own test
suite before anyone else is asked to pass it.

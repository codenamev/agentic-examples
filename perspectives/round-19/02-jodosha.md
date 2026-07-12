# Round 19 field notes — Luca Guidi runs the plan backwards

*Built: `examples/mirror_plan.rb` — every task ships its inverse,
so every plan carries a reflection: arrows flipped, undo for do.
Full mirror restores the world byte-for-byte; the mirror of a
crashed plan's completed prefix is a compensation saga, derived
rather than written.*

## What I built and why

Strange Ruby asks for the uncanny, and the uncanniest thing I know
in architecture is this: **the rollback you write by hand at 3am
was always just your plan, worn backwards.** So I made the mirror
literal. Each step declares `do:` and `undo:` as equals — reserve
and release, charge and refund, push and pop — and the mirror plan
is a mechanical derivation: reverse the topological order, swap
the lambdas. No new graph, no saga DSL. The reflection was in the
plan the whole time:

```
act 1: forward, then mirror - world restored byte-for-byte: true
act 2: dies at step 3, stock reserved, money TAKEN -
       mirror of the completed prefix runs - restored: true
act 3: mirror(mirror(plan)) == plan: true
```

Act 2 is the one that matters in production. A plan that dies
halfway with side effects committed is the classic distributed-
systems wound, and the standard treatments are all bad: manual
cleanup scripts, "eventual consistency" as a euphemism for hope, or
a saga framework with more concepts than your domain. The mirror's
version is: undo *exactly what completed*, in reverse order,
using inverses each step already declared. The plan's own execution
record (which steps finished) selects the compensation. Nothing is
invented at failure time — failure time is when you want to be
inventing *nothing*.

## The mandatory question

The honest fine print is the architecture. This works because every
inverse *truly* inverts, and some real actions have no inverse —
you cannot unsend an email; you can only send an apology. The
mirror's real contribution isn't the rollback; it's that it makes
"what is the undo?" a **mandatory question at design time**, per
step. Steps with a true inverse compose freely. Steps without one
get quarantined to the end of the plan, after everything
reversible has committed — which is precisely how careful teams
order side effects anyway, now enforced by a data shape instead of
a code review comment.

## Notes

- `mirror(mirror(plan)) == plan` — reflection is an involution, and
  yes, the darkroom and the mandala from round 18 would both like a
  word. Three rounds running, the strongest checks in this catalog
  are all "apply it twice, get identity."
- The world snapshot comparison is `Marshal.dump` equality — crude,
  total, and exactly right for a referee: byte-for-byte or it
  didn't restore.
- What I'd upstream: `add_task(task, undo: ->(t) {...})`, with the
  orchestrator deriving the compensation plan from its own
  execution state on failure. The framework already knows what
  completed; it's holding every ingredient of act 2.

## Verdict

Two mirrors, two byte-identical restorations, one involution. The
saga pattern turns out to be a *reflection*, not a framework — and
the discipline it buys (every step answers for its own undo) is
worth more than the rollback itself. Run your plans backwards once;
you'll write them differently forwards.

# Round 18 field notes — Rosa Gutiérrez opens the bakery

*Built: `examples/bakery_rush.rb` — two ovens, thirteen orders, one
queue. The same morning run twice under two disciplines
(first-come-first-served vs shortest-bake-first), scored in
customer sadness. Nothing changes but the enqueue order; eight
customers change their minds about you.*

## What I built and why

Round 14 I serialized tenants with a concurrency key. The brief
this time said "creative," and where I'm from the most serious
queueing system in any neighborhood is the bakery at seven in the
morning. A bakery is a queue wearing an apron: the plan is the
queue, the concurrency limit is the ovens (two; no negotiating with
ovens), and the *discipline* — who bakes first — is policy you
choose. Most queue systems ship FIFO as if it were a law of nature.
It's a default, and defaults have victims:

```
monday, first-come-first-served (two cakes hog BOTH ovens at 6am):
  mean wait 207ms; customers lost: 8
tuesday, shortest-bake-first (same ovens, same orders):
  mean wait 58ms; customers lost: 0
  cakes: done at 332ms and 351ms - both on time
```

Monday's failure is the one I've debugged in production a dozen
times wearing different clothes: two long jobs arrived first, took
every worker, and a crowd of two-second jobs aged out behind them.
The wedding cake was ordered first — but it's due at *noon*.
**Arrival order and deadline order are different orders**, and FIFO
conflates them. Tuesday bakes shortest-first (SJF provably
minimizes mean wait), the small orders fly, and the cakes — which
were never actually urgent — still beat their deadlines by a lap.

## The queue is the product

What makes the demo honest is that *nothing else changes*: same
ovens, same thirteen orders, same bake times, same patience
budgets. The only diff between monday and tuesday is the order the
tasks were added to the plan — enqueue order *is* the scheduling
discipline here, which is pleasingly literal. The referee demands
the full package: zero walkouts under SJF, provable walkouts under
FIFO (a discipline change you can't measure is a superstition), and
the cakes on time in both worlds — because a scheduler that saves
the croissants by ruining the wedding is not clever, it's just a
different outage.

## Notes

- Patience budgets are per-item SLOs, and "walked out" is an SLO
  breach with a face. I recommend this framing to anyone whose
  dashboards have gone emotionally abstract.
- SJF has a real failure mode the bakery hides: under continuous
  arrival of small jobs, the cake *starves*. Production wants aging
  (priority grows with wait) — the bakery version is "the cake gets
  an oven no later than 10am, no matter what."
- The plan-as-queue trick is worth naming: any orchestrator whose
  ready tasks start in add order gives you scheduling discipline
  for free. You're already choosing a discipline; FIFO just hides
  the choice.

## Verdict

Same bakery, two mornings, eight rescued customers, zero late
cakes. Queue discipline is a product decision wearing an
infrastructure costume — choose it like you chose the recipes, and
measure it in walkouts, not throughput.

# Round 20 field notes — Rafael França shepherds a removal

*Built: `examples/deprecation_shepherd.rb` — API removal as a data
problem: the shim delegates while counting every call with its
site, the gate consumes an observation window, and removal is
approved only at observed zero. The holdout is named, not shamed
into the void.*

## What I built and why

I have shepherded more deprecations than I can count, and the brief
asked for a common problem, so here is the one that follows every
maintainer home: **removing an API without breaking anyone.** The
industry's default protocol — print a warning for two releases,
then remove and brace — fails for a simple reason: warnings are
write-only. Nobody in the history of software was convinced by a
warning. What convinces people is a report with their name on it:

```
release 2.1: removal REFUSED - 8 calls from 3 sites
release 2.2: removal REFUSED - 1 call from 1 site:
             site_admin_refunds: 1 call this window
release 2.3: removal APPROVED - zero uses observed
```

Three rules, all of them data. The **shim delegates** — callers
keep working identically, because a deprecation that breaks people
is just a removal with extra steps and worse manners. While
delegating, it **counts every call with its call site**, because
"someone still uses this" is anxiety and "admin_refunds calls it
once nightly" is a pull request you can write before lunch. And the
**gate is falsifiable**: a fresh observation window, a
representative workload through it, and approval only at zero
observed uses. Time passing is not evidence. Traffic passing is.

## The window is the part people skip

Everyone instruments; almost nobody *windows*. Cumulative counters
tell you the API was used at some point since the dawn of metrics
— useless for a removal decision. The shepherd clears the ledger,
runs the representative workload, and reads what *that window*
says. Release 2.2's verdict is the payoff: one call, one site,
named. That's not a warning anybody has to notice; that's a work
item with an owner. Every deprecation I've actually finished ended
exactly this way — not when the changelog said we could, but when
the telemetry said nobody was standing in the doorway.

## Notes

- Attribution here uses `caller_locations` at the shim — one frame,
  cheap, and precise enough to name the calling method. Production
  wants sampling if the deprecated path is hot; identity of sites
  matters more than exact counts.
- "Representative workload" is load-bearing: a window that misses
  the nightly job approves a removal that breaks the nightly job.
  Window length is a judgment about your traffic's period — daily
  jobs need daily windows.
- The same gate shape works for feature-flag cleanup, config-key
  retirement, and dropping old API versions — anything where
  "unused" is a claim that should require evidence.

## Verdict

Eight calls became one became zero, the holdout was named at every
step, and the door closed only when the window was empty. A
deprecation warning is a hope; a usage ledger with call sites is a
plan. Remove APIs the way you'd close a road: after watching the
traffic, not after posting a sign.

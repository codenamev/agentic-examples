# Round 20 field notes — Evan Phoenix reloads without dropping

*Built: `examples/hot_config_reload.rb` — the long-running process's
oldest chore done right: build the new config aside, validate the
proposal, freeze it, swap one reference. The in-place strawman tears
35 of 120 requests on camera; the swap tears zero; the typo'd
config never touches the living.*

## What I built and why

Round 14 I built a socket server with a graceful drain. Same
neighborhood, next house over: **changing configuration under
traffic**, which every server eventually needs and every server
gets wrong once. The two classic wounds are both in the example,
bleeding measurably:

```
the in-place update (mutate the live hash, field by field):
  120 requests served, 35 saw a TORN config (limit != burst mid-swap)
the atomic swap (build aside, validate, freeze, assign once):
  120 requests served, 0 torn; config now v2
the bad proposal (rate_limit 500, burst 100):
  validation refused it; live config still v2, still serving
```

**Torn reads** first. The tempting reload edits the live hash field
by field, and any request in flight during the gap sees half old,
half new — rate limit from v2, burst from v1, and now the limiter
math is nonsense in a way no log line will ever explain. 35 of 120
requests caught it here, because the demo *made* the gap wide
enough to see. Production gaps are narrower and therefore worse:
rare enough to never reproduce, real enough to page you.

**The bad proposal** second. A reload that applies first and
validates never is how a typo'd YAML takes down what the deploy
didn't. Validation here checks *invariants* ("limit and burst ship
as a matched pair"), not just parse success — "valid YAML" and
"valid config" are different claims, and the second one is the one
your uptime depends on. The refused proposal leaves the old config
serving; the reload failed, the *server* didn't.

## Four verbs, no locks

BUILD the candidate as a separate object. VALIDATE it while it's
still a proposal. FREEZE it so nothing can tear it later. SWAP one
reference — which Ruby makes atomic for free, no mutex required,
because a single reference assignment is the one write that can't
be seen half-done. Requests in flight finish in the world they
started in: a request is a promise, a config file is a proposal,
and a server's whole job is never confusing the two. This is the
same reasoning as Puma's phased restarts, scaled down to one
object: never modify what's serving; stand up the new world beside
it and point.

## Notes

- The demo's first draft had the updater task added *after* all the
  traffic — so it ran after the requests and tore nothing. Torn
  reads need genuine interleaving; scheduling the saboteur into the
  middle of the add order was the fix, and it's a nice reminder
  that in this framework, add order is arrival order.
- The frozen config doubles as documentation of intent: anyone who
  tries to "just tweak" the live object gets a FrozenError instead
  of a production mystery. Make the wrong thing loud.
- Same skeleton covers feature-flag snapshots, routing tables,
  TLS cert rotation — anything read per-request and updated rarely.
  Read once at entry, keep the object, let the swap happen around
  you.

## Verdict

35 torn reads from the shortcut, zero from the discipline, one
refused typo, no dropped requests. Hot reload isn't a concurrency
puzzle — it's a bookkeeping promise: the world you started your
request in stays whole until you're done with it. Build, validate,
freeze, swap. Point at the new world; never redecorate the old one
while someone's standing in it.

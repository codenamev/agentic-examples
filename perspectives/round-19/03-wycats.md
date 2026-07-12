# Round 19 field notes — Yehuda Katz round-trips the DSL

*Built: `examples/plan_script.rb` — a bareword DSL where
`method_missing` is the parser, plus the principled half: the graph
decompiles to canonical source, the source re-parses to the same
graph, and emit reaches a fixpoint in one iteration.*

## What I built and why

Strange Ruby gets the trick everyone screenshots; I want the
principle it smuggles in. The trick: inside the block, `fetch_feed`
is not a variable, a method, or a symbol — it's `method_missing`,
catching an undefined name and declaring a step. `rank after:
dedupe` catches two. The whole parser is `respond_to_missing?` and
a Struct:

```
plan do
  fetch_feed
  dedupe after: :fetch_feed
  rank after: :dedupe
  render after: [:rank, :summarize]
end
```

That block above isn't my input — it's the *output*. The graph
decompiled itself to canonical PlanScript, and that's the half I
actually came to argue: **a DSL is a compiler, and compilers you
can trust are bidirectional.**

```
parse(emit(graph)) == graph:      true
emit(parse(emit(g))) == emit(g):  true (fixpoint)
compiled and executed the REPARSED graph: completed
```

I have spent a large fraction of my career on the boundary between
humans and object graphs — templates, config, conventions — and the
lesson that survives every stack: a format you can only *read into*
an object, never regenerate *from* it, is a one-way door. It ages
into folklore ("don't touch that file, nobody knows if it matches
production"). A round-trip format ages into a *file format*: safe
to commit, diff, regenerate, and — because emit is a normal form
with sorted deps and stable ordering — safe to machine-rewrite
without noise diffs.

## The fixpoint is the spec

`emit(parse(emit(g))) == emit(g)` at one iteration is a compact way
of saying three things at once: emit is deterministic, parse loses
nothing emit produces, and the normal form is *actually normal*
(re-normalizing changes nothing). It's the same shape as the
round-trip proofs scattered through this catalog — the darkroom's
involution, the mirror plan, plan_roundtrip back in round 6 — and
it's still the cheapest strong property I know. One equality, and
your DSL graduates from syntax to format.

## Notes

- The final referee compiles and runs the *reparsed* graph, not the
  original — pretty round-trips that produce dead objects are
  calligraphy. This one's output executes with dependency order
  intact.
- `method_missing` as parser is safe here because the DSL scope is
  a dedicated clean object — barewords have nowhere else to
  resolve. Do not do this in a scope with real methods; that's not
  strange, just cursed.
- What I'd upstream: `orchestrator.graph` already exposes
  everything emit needs. A `to_plan_script` (or to any canonical
  text form) on the framework side would give every plan in
  production a diffable, committable, re-runnable artifact for
  free.

## Verdict

Barewords in, graph out, source back, fixpoint reached, reparsed
plan green. The trick is three lines of method_missing; the
principle is that DSLs earn trust by round-tripping. One-way DSLs
age into folklore; this one is a file format now.

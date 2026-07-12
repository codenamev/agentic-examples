# Round 19 field notes — Steve Klabnik ports the borrow checker

*Built: `examples/borrow_checker.rb` — ownership semantics for task
outputs: move to exactly one consumer (who gains mutation rights),
deep-frozen borrows for everyone else, and double moves rejected at
assembly time with a proper `error[E0382]`.*

## What I built and why

The Strange Ruby brief is the only venue where this project is
socially acceptable, so: I brought the borrow checker to a language
with no memory to be safe about, and I regret nothing. The serious
observation underneath the bit is that **ownership was never really
about memory** — it's about answering "whose data is this?" at
every seam, and plan graphs have exactly the seams that question
haunts. Two downstream tasks read the same upstream output; one of
them mutates it; the other sees the mutation or doesn't depending
on scheduling. Every parallel framework has this bug in its
folklore. Rust's answer ports almost embarrassingly well:

```
scene 1 - one move (enrich) + one borrow (audit): borrow check PASSES
  the owner mutated freely: records grew to 3
  auditor's mutation attempt stopped by FrozenError (the borrow held)

scene 2 - both consumers demand a move:
  error[E0382]: use of moved value: `fetch.output`
    note: value moved to `enrich` here
    note: value used again by `audit` after move
    help: consider borrowing instead: mode: :borrow
```

Aliasing XOR mutation, one graph up: any number of borrows, at most
one move. The mover may mutate — that's what owning *means* — and
borrowers receive a deep-frozen copy, because in Ruby the only
reference nobody can mutate is a frozen one. The whole checker is a
Struct, a Hash, and `Marshal`.

## The crime is prevented, not avenged

The part I care most about is *when* scene 2 fails: at assembly,
before anything runs. Rust's compile-time rejection has no exact
Ruby analog, but "the moment the graph is declared and nothing has
executed yet" plays the role honestly — the double move never got
the chance to become a race. And the diagnostic is a love letter to
rustc on purpose: error code, the two sites *named*, and a `help:`
line with the actual fix. Error messages taught me more about
language design than type theory did; a checker that rejects
without teaching is just a bouncer.

## Notes

- The deep freeze on borrows is the honest cost, stated in the
  output: Ruby borrows are copies. Rust's zero-cost version needs
  the compiler; Ruby's version costs a Marshal round-trip and is
  still worth it at task-output granularity.
- The criminal auditor (mutating its borrow, caught by
  `FrozenError`) is runtime enforcement backing up the assembly
  check — belt and suspenders, or in Rust terms, the borrow checker
  plus a debug assertion.
- What I'd actually upstream: a `mode: :move | :borrow` option on
  the dependency declaration itself. The framework already pipes
  outputs to consumers; it knows the fan-out; it could enforce
  aliasing-XOR-mutation natively and reject double moves in
  `add_task`. The checker is 40 lines of glue that wants to be a
  framework feature.

## Verdict

One move, one borrow, one FrozenError, one E0382 — ownership
enforced in a language that never asked. The model was always
portable; only the compiler wasn't. Fearless concurrency starts
with writing down whose data it is, and any language can write
that down at the seam.

# Round 20 field notes — Tom Stuart programs with nothing

*Built: `examples/programming_with_nothing.rb` — FizzBuzz from
lambdas and nothing else: Church numerals, arithmetic, the Z
combinator, assembled in dependency order by a plan with a referee
per layer. The round's Why Day entry, chunky bacon implied.*

## What I built and why

This round's brief allows a few fun ones, and my idea of fun has
been on the record for over a decade: take everything away and see
what was actually necessary. No `Integer`, no `Boolean`, no `if`,
no `%` — just `->` and application, which Ruby graciously cannot
remove. From that single brick:

```
layer numerals        3/3 laws hold
layer arithmetic      4/4 laws hold
layer predicates + Z  6/6 laws hold
layer fizzbuzz        15/15 laws hold
1 2 Fizz 4 Buzz Fizz 7 8 Fizz Buzz 11 Fizz 13 14 FizzBuzz
```

Numbers are repetition (`NUMS[7]` applies a function seven times),
truth is selection (`TRUE_` picks its first argument), subtraction
is repeated predecessor — and the predecessor function remains the
one genuinely fiddly artifact in the whole tower, as it has been
since Kleene reportedly worked it out at the dentist. Each layer is
a plan task whose referee converts to native Ruby *only at the
boundary* to check the layer's laws; civilization is certified in
dependency order, arithmetic before the things that trust it.

## The Z combinator is the honest footnote

The famous Y combinator diverges under Ruby's strict evaluation —
it hands you your recursion before you've decided whether to use
it, and strictness uses it immediately, forever. The fix, Z, is Y
with an eta-expansion: wrap the recursive call in `->(v) { ... [v] }`
so it waits to be asked. The deep lesson hiding in that one wrapper
is that **evaluation order is a real dependency** — invisible in
everyday code because the language absorbs it, load-bearing the
moment you build without the net. MOD's true-branch is thunked for
the same reason. Laziness isn't a luxury feature; it's a place
where your language has been quietly making decisions for you.

## What the stunt is for

Nobody should ship Church numerals. The point is calibration: every
convenience your language hands you — numbers, conditionals,
recursion itself — is a library someone could have written in the
layer below, and *here someone did, in 25 lines*. Once you've seen
`if` built from selection and `%` built from subtraction-until-
less-than, language features stop being magic and become choices
with costs, which is the only sane posture from which to evaluate
any abstraction — frameworks included. The plan's layer-by-layer
certification is the same posture applied to bootstrapping: trust
nothing you haven't proven from the layer beneath.

## Notes

- Native strings appear only as the final selected *values* — the
  logic that selects them is all lambdas. Full string encoding
  (lists of numerals) exists in the long version of this bit; the
  margin of a 100-line example is too small to contain it.
- `to_integer` and `to_boolean` are the entire boundary, used only
  by referees. The tower itself never peeks.
- Happy Why Day. Build something unnecessary; measure it anyway.

## Verdict

Twenty-eight laws certified, fifteen correct FizzBuzz lines, zero
integers in the logic. Programming with nothing is the cheapest
available reminder that everything is something somebody built —
and that a referee per layer is how you'd want any civilization
bootstrapped, including the ones we ship on Fridays.

# Round 18 field notes — Marc-André Lafortune freezes a mandala

*Built: `examples/frozen_mandala.rb` — eight painter tasks, one
pure brush, frozen inputs. Symmetry and reproducibility fall out as
theorems; one painter's `Random.new` destroys both on camera.*

## What I built and why

Round 14 I audited Ractor-shareability and the moral was "send
facts, keep machines." Asked for something creative, I built the
aesthetic version of the same sermon: **referential transparency
you can look at.** A mandala's eightfold symmetry is usually
described as drawn. Mine is *entailed*: eight tasks run in
parallel with the same frozen inputs — a seed, a palette, one pure
brush `f(radius, angle, seed)` — and therefore produce the same
sector eight times. The painters never spoke. They didn't need to.
Identical inputs through a pure function *are* the coordination.

```
symmetry:        all 8 sectors identical - the pattern IS the purity
reproducibility: two runs, byte-identical - same seed, same art, forever

then painter 3 discovers ambient entropy:
symmetry:        broken - sector(s) [3] no longer match
reproducibility: broken - the same seed painted two different mandalas
```

Reproducibility is the same theorem run twice: seed 42 yields this
exact mandala, byte for byte, today and in ten years. Generative
artists sign their seeds for this reason; it's the only signature
that regenerates the work.

## One `Random.new`, two dead theorems

The sabotage is a single line — painter 3 reaches for unseeded
`Random.new` ("it's called FEELING") — and both properties die
*simultaneously*, which is the precise lesson. Impurity never
breaks one guarantee; it breaks the *class* of guarantees, because
they were all corollaries of the same premise. The demo catches it
twice over: sector 3 no longer matches its siblings (symmetry is a
cross-worker assertion), and the same seed paints two different
mandalas (reproducibility is a cross-run assertion). Art turns out
to be the ideal domain for this failure because you can *see* it —
nobody needs a debugger to notice a mandala with a rash.

## Notes

- The purity contract here is social, not enforced — Ruby will
  happily let a lambda touch entropy. The Ractor version would make
  the freeze literal (unshareable state can't cross), which is
  exactly the trade from my round-14 notes: machines stay home,
  facts travel.
- "Regression-test your beauty" is a joke that isn't: `first ==
  second` on the full sector data is a golden-master test of an
  artwork, and it costs one comparison. Any deterministic generator
  deserves one.
- The polar renderer (cartesian grid → radius/angle → sector →
  bucket) is 20 lines and reusable for any radially symmetric
  output — clocks, radar plots, pizza dashboards. I mention pizza
  advisedly.

## Verdict

Eight silent painters, one entailed symmetry, one byte-stable
artwork — and a single unseeded random that shattered the whole
theorem set at once. Purity isn't a style preference; it's the
load-bearing structure, and for once the structural failure is
visible from across the room.

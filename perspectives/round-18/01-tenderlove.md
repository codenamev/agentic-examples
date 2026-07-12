# Round 18 field notes — Aaron Patterson starts a band

*Built: `examples/terminal_band.rb` — four instruments composing in
parallel from one chord chart, a mixer that reads every part by
name, and a harmony referee with blame attribution. A theremin is
fired over math.*

## What I built and why

The brief said "creative," which I choose to interpret as "Aaron,
you may finally expense the band." So: the Terminal Band. Four
players — bass, melody, harmony, and a theremin we hired during a
weak moment — each composes its sixteen ticks as an independent
task. No shared state, no coordination, no rehearsal. Just the
chart: I-IV-V-I in C, the progression so reliable it should be in
the standard library.

```
referee: dissonance at ticks 3, 7, 11, 15 - and removing only
"theremin" resolves every one of them.
set two, as a trio: sixteen ticks, zero dissonance - the band is TIGHT
```

The joke is load-bearing, which is my favorite kind of joke. The
players composing in parallel with only the chart between them is
*exactly* the fan-out pattern from every serious example in this
catalog — the contract replaces coordination, and consonance is an
emergent property of everyone honoring it. The theremin is what
happens when one worker treats the contract as a suggestion: its
tritones land on ticks 3, 7, 11, 15 (it waits for the barline, like
a coward), and suddenly the *combined* output violates a property
no individual part can see.

## Bisection wearing a bow tie

The referee does two jobs. First the falsifiable claim: at every
tick, all sounding pitch classes must be pairwise consonant — no
seconds, no sevenths, no tritones (interval math: `(a - b) % 12` not
in `[1, 2, 6, 10, 11]`; music theory is just modular arithmetic
with feelings). Second, and better: **blame attribution.** When the
claim fails, remove one player at a time until it holds. The
minimal input whose absence resolves every clash is your culprit.
That's delta debugging — bisection wearing a bow tie — and it works
on band members exactly as well as on commits.

## Notes

- Drums were excluded from the harmony check on the grounds that
  they are unpitched, enthusiastic, and litigious.
- The mixer reads tracks via `needs:` — when your fan-in has four
  inputs, naming them isn't ceremony, it's the difference between
  "the theremin part" and "argument three."
- Serious extension, same skeleton: replace notes with any
  per-worker output and the referee's shape survives — a combined
  property checked per window, with remove-one attribution when it
  fails. I will be describing this at RubyKaigi as "the theremin
  pattern" and nobody can stop me.

## Verdict

Sixteen ticks, one firing, zero dissonance in the final mix. The
plan gave me parallel composition for the price of a chord chart,
and the referee turned "someone's ruining the song" into "it's the
theremin, at these ticks, provably." Music is the one domain where
"works on my machine" was never a defense — everyone can hear it.

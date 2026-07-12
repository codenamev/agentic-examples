# Round 18 field notes — Janko Marohnić opens the darkroom

*Built: `examples/ascii_darkroom.rb` — a photo pipeline where the
photos are characters and the chemistry is arithmetic: one sacred
negative, one develop step, three derivative baths in parallel,
promotion to the store, and darkroom rules as the referee.*

## What I built and why

Round 14 I built the serious version — cache-then-promote with a
journal. Told to be creative, I built where that architecture
actually comes from: a **darkroom**. Every file-attachment library
is a darkroom with worse lighting. The original is a negative you
protect with your life; developing is the one expensive step;
derivatives are cheap baths off the same print; and nothing is real
until it's promoted to the store. Shrine's whole design falls out
of taking that metaphor literally, so this example takes it
literally — a moon over mountains, 36×14, ten shades of ASCII.

```
darkroom rules: negative untouched (checksummed); derivatives are
NEW files, never edits; develop(develop(x)) == x, proven; the
thumbnail is really 18x7; all three baths promoted: yes
```

The plan shape is the architecture: `develop` is the shared
dependency, and contrast, thumbnail, and vignette fan out from its
*output* in parallel — they share a dependency, not chemistry. No
bath re-reads the negative; no bath sees another bath's water.
That's the isolation rule that makes derivative pipelines safe to
parallelize, expressed as graph edges instead of discipline.

## The involution is the check I wish every pipeline had

`INVERT.call(print) == NEGATIVE` — develop the developed print and
you must get your negative back, exactly, all 504 pixels. A
transform that can't round-trip is a transform quietly eating data,
and in a darkroom you find out when the wedding photos are already
gone. Real pipelines have the same theorem wearing different
clothes (encode/decode, serialize/parse, upcase... no, not upcase),
and it costs one equality. The other rules are equally cheap and
equally absolute: the checksummed negative (originals are
append-only in spirit), dimension contracts per bath (a vignette
that resizes is a bug with mood lighting), and promotion verified
by files actually existing in the store.

## Notes

- The thumbnail is a 2×2 box filter — four pixels average into one,
  18×7 from 36×14. Downscaling in a plan task means the *expensive*
  variants parallelize free when you add formats later; this is
  exactly why Shrine computes derivatives off one cached original.
- The negative being *procedural* (a lambda exposed it, not an
  artist) is quietly the marcandre point from next door: same
  function, same moon, every run. Deterministic fixtures make
  golden checks possible.
- Left as an exercise with teeth: a `promote` task that renames
  atomically and a journal entry per derivative — my round-14
  example has both, and the two examples compose into one honest
  upload system.

## Verdict

One negative, one print, three parallel baths, five rules all
holding. The darkroom teaches the attachment pipeline better than
any README I've written: protect the original, develop once, bathe
in parallel, promote explicitly — and prove your transforms can
round-trip before the wedding.

# Round 19 field notes — Piotr Murach ships a demo intro

*Built: `examples/terminal_demoscene.rb` — parallax starfield,
plasma, and a wrapping scroller in 64 columns, rendered by a plan
shaped like a render farm, with a physics referee proving each
effect obeys its own law. The crowd (the exit code) goes wild.*

## What I built and why

I've spent years building TTY tools that treat the terminal as a
serious canvas, so for the strange round I went to the culture that
treated it as a *stage*: the demoscene. And the demoscene's open
secret is the punchline of this whole example — it was the most
rigorous software culture ever built by teenagers. No memory to
waste on state meant every effect was a **pure function of the
frame counter**, and pure functions of a counter are *checkable
math*:

```
physics referee: scroller rotation law holds on all 8 frames;
10 stars conserved with 2:1 parallax; plasma period is exactly 24
(equal at f+24, different at f+12); every frame 13x66
```

The scroller is modular arithmetic (`text[(p + f) % n]` — asserted
per column, per frame). The parallax is two velocities (the fast
layer provably moves 2 columns per frame to the slow layer's 1).
The plasma's period is an LCM — 24 frames, verified both ways:
equal at f+24 *and different at f+12*, because a periodicity check
without the inequality half would pass for a static image, and
static plasma is just wallpaper with a marketing budget.

## The render farm fell out for free

Every frame's three effects compute in parallel as tasks — no
mutex, no ordering, no shared anything, because pure functions
don't fight. The compositor fans them in **by name**
(`t.needs.stars`, `t.needs.plasma`, `t.needs.scroll` — layer
compositing with named layers, as nature intended), and the reel is
one more fan-in. Eight frames × four tasks scheduled under one
ceiling: the plan is structurally identical to a production render
farm, at 1/10⁹ the pixel budget. Shape survives scale in both
directions; that's why it's a shape.

## Notes

- The filmstrip degrades gracefully by design: no ANSI escapes, no
  cursor games, just bordered frames on stdout — because this runs
  in CI where there is no TTY, and an example that only works on a
  living terminal is a demo that crashes at the party. (The TTY
  version with cursor-home animation is a ten-line wrapper; the
  physics referee wouldn't change at all, which is the point.)
- Frame dimensions asserted uniform across the reel — the dullest
  check in the file and the one that catches real compositor bugs
  first. Borders don't lie.
- Greetings, as tradition demands, to every persona in this
  catalog. The scroller had room.

## Verdict

Three effects, eight frames, four laws, zero mutexes. The demoscene
knew the catalog's deepest lesson decades early: determinism isn't
a constraint on art — it's what lets you *prove* the art does what
the crowd thinks it's seeing. Sixty-four columns, and every pixel
under oath.

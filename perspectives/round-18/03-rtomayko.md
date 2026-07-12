# Round 18 field notes — Ryan Tomayko screens the negative

*Built: `examples/journal_cinema.rb` — the execution journal played
back as a movie: same scenes, same order, same rhythm, compressed
4x, with a referee that checks the projection is faithful to the
negative. The compile failure isn't a log line; it's a scene with
a comeback.*

## What I built and why

Round 14 I forked processes. This round said "creative," and the
most creative thing I know is also the oldest trick I have: show
the terminal *moving*. Half of what I ever taught about Unix landed
because of animated terminal sessions — not because the words were
better, but because a sequence you *watch* gets stored in the part
of your head that remembers stories, not the part that loses grep
output.

The journal was already a movie. Every plan run leaves a negative
in a JSONL can: who started, who failed, who came back, millisecond
timecodes on every frame. Nobody watches the actual run — that's
the point of automation — so the run is a film shot with no one in
the theater. Playback is thirty lines: parse timestamps, sleep the
gaps scaled by the projection speed, print the scenes.

```
00047ms  [ DRAMA! ]  compile assets (sass compiler mood - but the
                     negative says they came back)
00884ms  [ ACTION ]  compile assets
00927ms  [  CUT   ]  compile assets
```

Look at that gap — 47ms to 884ms. That's the retry backoff, and in
a log file it's an invisible subtraction you'd have to do by hand.
On a screen with a playhead it's *dead air*, and dead air is
something humans notice instantly. The projection made the backoff
policy visible without a single chart.

## Faithful projection or nothing

The referee holds the projector to documentary standards: every
frame from the negative, in order, none dropped; the comeback arc
(a failure followed by the same task's success) must survive the
edit; and the projection must actually run at the advertised speed,
measured. A replay tool that drops frames or reorders them isn't a
projector, it's an unreliable narrator — and incident review has
enough of those already, most of them eyewitnesses.

## Notes

- Incident review as film club: watching last night's footage beats
  interviewing witnesses. The negative doesn't misremember, doesn't
  compress the boring parts unless you ask, and has timecodes.
- Obvious sequels: `--speed 30` for long runs, a `--from`/`--to`
  playhead, and side-by-side projection of two negatives (last good
  deploy vs the bad one) — a diff you watch.
- The journal's tolerant replay means a torn final frame doesn't
  burn the whole reel. Projectors should survive damaged film; this
  one inherits that from the framework.

## Verdict

Ten frames, order preserved, comeback intact, 4.0x as requested.
The journal held everything a movie needs — cast, scenes, drama,
timing — and the projector is barely code. Evidence with a playhead
beats evidence with a grep prompt.

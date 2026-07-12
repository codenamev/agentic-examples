# Round 18 field notes — Akira Matsuda rings the gong

*Built: `examples/lightning_talks.rb` — five speakers, one podium,
a hard gong. Cooperative cancellation at slide boundaries, timeout
enforced by the stage rather than the speaker, and a session that
ends on time because bounded talks compose into bounded sessions.*

## What I built and why

Round 13 I paginated a journal. This round asked for creativity,
and the most creative piece of engineering I know isn't a gem —
it's a conference format. The lightning talk is our culture's
greatest API: **a hard timeout with applause.** Five minutes, one
gong, no exceptions, not even for the keynote speaker, *especially*
not for the keynote speaker. I have watched this format end on time
in four languages and two hemispheres. Nothing else in software
does.

```
dr_rambles   A Brief History of Everything (pt. 1/40)   9/30
             GONG at 55ms - slide 9, mid-gesture
referee: session ran 234ms against a worst-case budget of 250ms
```

So I built the stage. One podium (`concurrency_limit: 1` — the
single most honest use of that parameter in this whole catalog),
speakers as a dependency chain, and the gong checked **between
slides**. That placement is the design: you can't interrupt a slide
mid-sentence, but you can absolutely decline to show the next one.
This is cooperative cancellation at safe points — the same shape as
canceling any work that holds state — wearing a conference lanyard.

## Three conference-tested rules

1. **The gong belongs to the stage, not the speaker.** dr_rambles
   believed sincerely, in their heart, in slide 30. Enforcement
   that lives in the worker is a promise; enforcement that lives in
   the harness is a property. (My deepest apologies to dr_rambles,
   who I am sure will cover the remaining 21 slides in parts 2
   through 40.)
2. **Timeboxes compose.** Five bounded talks make one bounded
   session — the referee checks the session against `5 × LIMIT` and
   it holds by *construction*, not by hope. This is why the LT block
   is the only part of any conference that never runs late.
3. **Check at boundaries you can actually stop at.** The gong lands
   "within one slide of the limit" — bounded lateness, declared
   honestly. A timeout that pretends to be instant is lying about
   its granularity; ours states it.

## Notes

- The punctual speakers finishing untouched matters as much as the
  rambler being gonged — a gong that clips good citizens is just
  jitter with a superiority complex. The referee checks both
  directions.
- Real deadline for the same skeleton: slice any long-running agent
  (LLM calls per chunk, batch jobs per page) and check the budget
  at slice boundaries. Timeboxes beat promises, in talks and in
  tasks.
- I did consider building pagination for poems instead. The gong
  told me my five minutes were up.

## Verdict

One rambler gonged mid-gesture, four rounds of applause, a session
16ms under its worst case. The lightning talk survives every
conference because its guarantee lives in the format, not in the
speakers — which is precisely where every guarantee in this
framework wants to live too.

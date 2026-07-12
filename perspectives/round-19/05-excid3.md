# Round 19 field notes — Chris Oliver hits record

*Built: `examples/auto_screencast.rb` — a plan that records its own
tutorial: narration, code fences, and actual outputs emitted as a
markdown episode, then played back — the fences re-executed fresh
and required to reproduce their own `# =>` lines. Tampering is
caught by the episode itself.*

## What I built and why

I've recorded hundreds of episodes, and the recurring nightmare
isn't stage fright — it's the episode that *doesn't run on the
viewer's machine*. You cut a screencast against last month's gem,
somebody follows along today, step 3 explodes, and the comment
section becomes a support queue. Told to embrace the strange, I
built the tutorial that refuses to exist in that state:

```
recorded: 4 scenes -> episode-042.md
playback: 4/4 fences re-executed in a fresh context
every replayed output matches the recording: true
tampering (0.9 -> 0.8 in the markdown): playback catches 2 scenes
```

The recording session is a plan: each scene is a task carrying
narration and code, and the *executing step itself* captures the
output that becomes the fence's `# =>` annotation. The camera is
inside the take. Then the strange half: the finished markdown is
**played back** — fences extracted, re-run in a fresh context, and
required to reproduce their own annotations. The tutorial is a
doctest of itself, and it ships with its repeat button installed.

## The tamper reel is the best scene

An "editor" improves the discount inside the published markdown —
`* 0.9` becomes `* 0.8`, the kind of drive-by copyedit every
long-lived tutorial accumulates. Playback catches **two** scenes:
the edited one, *and* the receipt scene downstream whose recorded
total no longer matches. That's the chained-context design earning
its keep — because scenes share one `ctx`, corruption propagates,
and the episode convicts its editor with cumulative evidence. A
tutorial whose examples are independent can only catch the edited
line; a tutorial that's secretly one program catches the lie's
consequences too.

## Notes

- One rule, applied twice: **code you show must be code you ran.**
  Recording enforces it forward (the annotation IS the output);
  playback enforces it backward (the output must be reproducible).
  The doctest runner in agentic's `bin/` enforces the same rule for
  API docs; this is the narrative-tutorial version.
- The episode format is deliberately boring markdown — title,
  prose, fence, annotation. Boring formats get committed to repos
  and rendered by everything; the innovation budget went to the
  playback loop.
- Real-world version: record against the gem in CI on every
  release; a failing playback means the tutorial and the gem have
  diverged, and you find out before the comment section does. This
  is buildable today with the journal as the recording medium.

## Verdict

Four scenes recorded mid-plan, four fences replayed faithfully, one
tampering editor convicted by cumulative evidence. Tutorials rot
because they're transcripts of a run nobody can repeat — so make
the tutorial *be* the run, and teach the episode to check its own
work before it teaches anyone else.

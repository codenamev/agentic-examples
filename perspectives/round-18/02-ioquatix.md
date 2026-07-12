# Round 18 field notes — Samuel Williams stages a fireworks show

*Built: `examples/fireworks_show.rb` — a pyrotechnic score as a
plan: volleys as dependency layers, a five-shell finale that must
burst together, and the same show run with one igniter versus a
full crew. The burst timeline is the argument.*

## What I built and why

I've spent years explaining async with throughput charts — requests
per second, connections held, workers kept busy. All true, all
faintly dishonest about *why the model matters*. The purest case
for concurrency isn't doing more per second; it's the thing that
cannot exist sequentially at all: **simultaneity as a requirement.**
A fireworks finale is five shells that must burst *together*. Not
quickly. Together.

```
finale spread: intern 201ms (a sad trickle of #-marks)
               crew   0ms (one vertical WALL of sky)
show length:   intern 660ms vs crew 203ms
               (650ms of total fuse burned either way)
```

The score is a plan and nothing but a plan. Volleys are dependency
layers — volley two waits on volley one, which is what rhythm *is*
structurally. The finale is a fan-in whose five tasks become ready
in the same instant; whether they *fire* in the same instant is
purely a question of how many fuses the executor can hold. One
igniter produces a diligent, correct, and artistically bankrupt
trickle. Eight fibers produce a wall. Same score, same total fuse
burned — parallelism isn't faster fire, it's fire *arranged in
time*.

## The show is honest about what it measures

Both runs execute the identical plan, so every difference in the
timelines is attributable to the concurrency limit alone — the demo
is its own control group. And the referee's two assertions are the
two halves of the thesis: the crewed finale spread must be a wall
(< 20ms), and the intern's must be provably a trickle (> 3× worse).
An example that only showed the pretty case would be advertising;
showing the failure mode under the same score is what makes it an
argument.

## Notes

- The burst records collect into a plain hash from concurrently
  running fibers — safe here because the fiber scheduler runs them
  on one thread. That sentence is doing a lot of work, and it's why
  I keep saying "structured concurrency" instead of "threads."
- The ASCII timeline (one row per shell, column = burst time) turned
  out to be the best Gantt chart I've drawn on this framework, and
  it cost twelve lines. Time-position rendering is criminally cheap.
- Serious twin, same skeleton: replace shells with cache warmers
  that must go live within one deploy window, or with the N reads
  of a quorum. "Together" is a production requirement more often
  than we name it.

## Verdict

One score, two executors, and a finale that only exists above
concurrency five. The plan expressed rhythm as dependencies and
simultaneity as fan-in readiness, and the scheduler turned the
second into a wall of sky. Async's best sales pitch was never
throughput — it's that some choreography is impossible alone.

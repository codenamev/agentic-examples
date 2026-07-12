# Round 19 field notes — Sam Saffron watches the watcher

*Built: `examples/observer_effect.rb` — the workload run under 0,
1, 2, and 3 layers of profiling probes, the observer tax derived
per glance (~174ns), linearity verified, and the workload's answer
asserted unchanged under observation.*

## What I built and why

I've shipped always-on profilers to a lot of production servers,
and the question I'm asked least is the one that should be asked
first: **what does the measuring cost?** Everyone audits the
workload; nobody audits the watcher. For the strange round I built
the missing experiment — instrumentation instrumenting itself:

```
observers  wall (min)   overhead    events per run
0          2.51ms       -           0
1          5.87ms       +3.37ms     20000
2          9.45ms       +6.94ms     40000
3          12.97ms      +10.46ms    60000

observer tax, derived: ~174ns per glance
linearity: 1 layer costs 3.37ms; a third of 3 layers costs 3.49ms
```

Each probe does exactly what real profilers do per sample — read
the clock, append an event — and the layers stack the way nested
instrumentation stacks in real apps (APM over rack-mini-profiler
over a StatsD hook, each watching roughly the same work). The tax
comes out beautifully linear: one layer costs 3.37ms, a third of
three layers costs 3.49ms. Which is what you want! **A profiler
whose cost curves is a profiler with a bug** — superlinear overhead
means your probes are contending with each other, and now you're
profiling your profiler's lock, which is this example one level
deeper and considerably less fun.

## The methodology is the product

Three choices worth stealing. *Min-of-five*, not mean: the minimum
is the least-disturbed run, and disturbance is exactly what we're
isolating. *The answer asserted unchanged*: the workload computes a
checksum, and all four depths must agree — a probe that touches the
physics isn't an observer, it's a participant, and every profiler
bug I've ever hated was a participant. And *one lane*
(`concurrency_limit: 1`): timing tasks in parallel measures your
scheduler, not your code — the same confession ko1's periscope
makes two exhibits over.

## Notes

- ~174ns per glance sounds free until you multiply: at one glance
  per unit of work and real request rates, that's the CPU cost of
  the pretty flamegraph, denominated in requests you could have
  served. Usually worth it — visibility pays rent — but "usually"
  is a measurement, not a vibe. Now it's a measurement.
- The number is machine-specific by design; the *method* is the
  artifact. Run it on your hardware; put your own number in your
  runbook.
- Pairs with vm_eye: ko1 counts what the VM saw, I price what the
  seeing costs. Between the two runs of this round, observation has
  both a ledger and an invoice.

## Verdict

Four depths, one unchanged checksum, a linear tax of ~174ns per
glance. Watch everything — visibility is how systems stay honest —
but the first thing any watcher should measure is itself, and now
there's a 90-line example that does it with an exit code.

# Round 20 field notes — Jeremy Evans audits the pool

*Built: `examples/connection_pool_care.rb` — the incident with the
most misleading symptoms, reproduced and cured: a leaky checkout
drains the pool one unhappy path at a time; exhaustion errors
arrive with receipts naming every holder; the block form ends the
species.*

## What I built and why

The brief asked for a common problem. This is the commonest one I
know that still gets misdiagnosed weekly: **the database is fine,
the app is fine, and nothing works**, because the connection pool
drained one leaked checkout at a time. The leak is always the same
four lines — a checkout without an ensure, an exception on the
unhappy path, a connection that never comes home:

```
the leaky version:  served 19; pool now holds 0/5
  6 jobs hit exhaustion, and the error came with RECEIPTS:
  job 5 waited past timeout; pool of 5 exhausted. current holders:
    conn-1 held by job 3 for 52ms
the block-form version: served 23; failed cleanly 7; exhausted 0
  pool restored to 5/5 - every connection came home
```

Two disciplines, both in Sequel since before it was fashionable to
have opinions about this. First: **the block form is the API.**
`checkout`/`checkin` as separate public methods is rope — every
caller must remember `ensure` on every path, forever, including the
paths that only exist when the payment provider times out. `with`
puts the `ensure` in exactly one place, written by the person who
understood the invariant. Same failure rate in both runs; the block
version returned every connection *including from the seven
failures*, because `ensure` doesn't care why you're leaving.

Second: **the pool keeps receipts.** The exhaustion error names
every current holder and their hold time. This is the difference
between "the database is slow??" at 3am and "job 3 has held conn-1
for 52ms and never checks in" — attribution at the moment of pain,
not archaeology from connection graphs three hours later.

## Exhaustion punishes the innocent

The demo makes visible the property that makes these incidents so
politically confusing: the jobs that *hit* exhaustion are not the
jobs that *caused* it. Job 3 leaked; job 5 paid. By the time the
pool is dry, the guilty parties have all exited with their original
exceptions, looking like ordinary failures, and the timeout errors
land on whoever arrived next. This is why pool incidents always
look like someone else's fault — and why the receipts matter: they
point backward at the holders, not forward at the victims.

## Notes

- The demo's own first draft had all five leaks but zero exhaustion
  errors — twenty jobs meant the last leak took the last connection
  after everyone else was served. Ten more jobs put innocents
  behind the drought. Even the demonstration needed victims to
  arrive after the crime, which is the incident's whole structure.
- Timeout on checkout is not optional. An unbounded wait converts
  "pool exhausted" into "app hung," which pages a different team
  and doubles the diagnosis time.
- Real pools add: hold-time warnings before exhaustion (a
  connection held 10× the median is a leak in progress), and
  fiber/thread-owner assertions so a checkin from the wrong context
  fails loudly.

## Verdict

Five leaks, six innocent victims, one error message that solved the
case at the moment it hurt — then the same workload, block-formed,
with every connection home and the pool at 5/5. Don't give callers
rope; give them a block. And make your pool testify.

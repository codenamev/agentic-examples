# Round 18 field notes — Mike Perham plays pinball

*Built: `examples/pinball_queue.rb` — the whole gospel of background
jobs on one pinball table: drains are transient failures, the ball
save is a bounded retry, TILT is poison that goes to the trough
unretried, and the scoreboard practices double-entry bookkeeping.*

## What I built and why

Asked for creativity, I did the most creative thing available to a
person with my reputation: I explained retries with a toy. Because
here's the industry secret — the pinball machine already solved job
queues, mechanically, decades before any of us. Every policy I've
shipped or argued about in a decade of Sidekiq is on the table:

```
ball-2 (rattles the drain)   12000 points after 1 ball save
ball-4 (TILT machine)         TILT -> the trough (dead letters)
ball-5 (drains twice!)       25000 points after 2 ball saves
FINAL SCORE: 49000   launched: 5, scored: 4, in the trough: 1
```

- **The drain is a transient failure**, and the *ball save* kicks it
  back automatically. That's a retry: automatic, bounded (the save
  has a budget — drain a fourth time and your turn is simply over),
  and backed off. Nobody stands at the machine manually re-plunging
  every drained ball, which is nonetheless how half the industry
  handles exceptions.
- **TILT is poison.** You do not ball-save a tilt. The machine ends
  the turn *on purpose*, because the failure isn't in the ball, it's
  in how the ball is being played — retrying it just tilts twice.
  Non-retryable by decree; the framework's failure taxonomy carries
  the decree into the plan.
- **The trough is a queue, not a void.** The tilted ball sits where
  a human can review it after the game. Dead letter offices earn
  their name by being *offices* — staffed, visited, emptied — not
  oubliettes.

## The ledger is the boring part, which is why it's the point

The referee runs double-entry bookkeeping: balls launched equals
balls scored plus balls troughed, attempt counts match policy
exactly (the tilt played once, the double-drainer played three
times), and the *instant replay* — the journal — shows precisely
three drains on tape. Exciting things happen on the playfield so
that nothing exciting ever happens to the ledger. If your queue's
ledger is where the excitement lives, you don't have a queue, you
have a mystery.

## Notes

- Two flippers = `concurrency_limit: 2`. Every arcade kid knows you
  can't play five balls with two flippers; capacity planning via
  quarters.
- The journal-as-instant-replay pairs beautifully with rtomayko's
  projector from this same round. The tape doesn't lie; the
  scoreboard reconciles against it.
- What the table teaches that dashboards don't: failure handling is
  *physical policy* — springs, budgets, and a trough — not vibes in
  a rescue block. Make your policies that legible and on-call gets
  quieter.

## Verdict

Five balls, three drains saved by policy, one tilt sent to the
humans, a scoreboard that balances to the point. Boring reliability
plays great on a playfield: bounded retries for the transient, dead
letters for the poison, and a ledger nobody ever has to wonder
about.

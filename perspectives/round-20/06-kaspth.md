# Round 20 field notes — Kasper Timm Hansen ships the drip

*Built: `examples/drip_campaign.rb` — the onboarding sequence every
product ships, with its three classic bugs reproduced and cured: an
idempotency ledger beats the double-fired cron, unsubscribes are
checked at send time, and every offset runs on the user's own
clock.*

## What I built and why

The brief said common problems, and few are more common — or more
publicly embarrassing — than drip campaign bugs, because the
failure mode arrives in someone's inbox with your logo on it. The
three species, all present in the demo week:

```
day 0  welcome -> ana, bo, di     day 1  welcome -> cy
day 3  tips -> ana  (cron fired TWICE this day; outbox can't tell)
day 4  tips -> cy   (their clock, not the calendar's)
day 7  upsell -> ana
bo: welcome only (unsubscribed day 2)
di: welcome only (unsubscribed the MORNING of their tips day)
```

**The double send.** Cron fired twice on day 3 — it always
eventually does — and the outbox is identical to the single-fire
world, because sends are recorded in a ledger keyed `(user, step)`
and the ledger is consulted before the mailer. Scheduling is
allowed to be sloppy; delivery is not. Put the guarantee at the
narrow waist.

**The ghost mail.** di unsubscribed the morning of their tips day.
A system that checks unsubscribes when it *schedules* would have
mailed them — the decision was made Monday for a Thursday send, and
Monday's answer expired. The check lives at **send time**, the last
possible moment, because consent is a fact with a timestamp, not a
constant.

**The cohort smear.** cy signed up a day late and their entire
sequence shifted with them — welcome day 1, tips day 4 — because
offsets are computed from the user's signup day, not from the
campaign's launch date. Batch thinking ("send tips to everyone on
Thursday") is how day-0 users and day-3 users end up in the same
undifferentiated soup.

## The referee caught its author on arithmetic

My asserted outbox size was 6; the correct answer is 7 — cy's
upsell lands on day 8, outside the simulated week, and I'd
mentally truncated their sequence while writing the assertion. An
off-by-one on *someone else's clock* is precisely the bug class
this example warns about, and I committed it in the test for it.
The exactness of the referee (whole-outbox equality, not "roughly
n mails") is what surfaced it in seconds.

## Notes

- The ledger is a `Set` here and a unique index in production —
  `(user_id, step)` with the insert-or-skip in one statement. The
  shape is identical; the database just makes it honest under
  concurrency.
- The right thing is the *only* thing in this design: there is no
  code path that sends without consulting the ledger and the
  unsubscribe list, because the checks live inside the send task,
  not beside it. Defaults you can route around are suggestions.
- Same skeleton runs any time-offset sequence: trial-expiry
  reminders, dunning, review-request follow-ups, NPS surveys. The
  three bugs and three cures transfer without edits.

## Verdict

One double-fired cron absorbed, two unsubscribes honored to the
morning, one late signup on their own clock, and an author caught
by his own exact referee. Drip campaigns don't need a marketing
platform — they need a ledger, a late check, and per-user
arithmetic, which is to say: they need the right thing to be the
default thing.

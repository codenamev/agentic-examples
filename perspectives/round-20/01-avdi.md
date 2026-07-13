# Round 20 field notes — Avdi Grimm posts a doorman

*Built: `examples/carrier_quotes.rb` — the most common integration
problem in commerce (three carrier APIs; one slow, one down, one
schema-drifted) solved confident-style: all suspicion spent once at
the boundary, a core with zero nil checks, and a checkout that
never loses the sale.*

## What I built and why

The round's brief is "solve a common problem," and I picked the one
that generates more timid code than any other: **calling APIs you
don't control.** The standard failure isn't the outage — it's what
the outage does to your codebase. One timeout in production and
suddenly every method within three files of the integration grows
`if response && response[:price] && ...` scar tissue, and the
business logic disappears under archaeology of fear.

```
TurtleShip: $8.99 in 5d
FedUp: unavailable (no answer within 50ms)
ParcelPanic: unavailable (malformed response: [:cost, :eta])
-> checkout shows: TurtleShip: $8.99 in 5d (2 degraded, sale not lost)

the apocalypse (every carrier asleep):
-> checkout shows: FlatRate fallback: $12.0 in 7d (the store stays OPEN)
```

The confident-code answer is a *doorman*: `quote_from` is the only
method in the file allowed to be afraid. It converts every possible
outcome — success, timeout, schema drift, raised exception — into
an object with the same face: `Quote` or `Unavailable`, both
answering `available?`, `cents`, `to_s`. Past the door,
`choose_rate` reads like the business rule it is: pick the cheapest
available; if none, flat-rate fallback; never lose the sale. Not
one nil check. Not one rescue. The core doesn't ask "but what if?"
because the door already answered.

## The degraded keep their reasons

`Unavailable` isn't a null object that shrugs — it carries *why*
("no answer within 50ms", "malformed response: [:cost, :eta]"),
because ops will want those reasons tonight and the business wants
them aggregated by Friday. Graceful degradation without preserved
reasons is just silent failure with better posture. And the
apocalypse scenario matters as much as the ordinary afternoon: all
three carriers down still produces a *usable answer* (flat rate,
flagged as fallback), because "we couldn't compute shipping" is a
sentence that should reach a dashboard, never a customer.

## Notes

- The fan-out earns its keep quietly: three carriers in parallel
  under one plan means FedUp's 200ms nap never delays TurtleShip's
  10ms answer. Sequential integration code pays the slowest
  carrier's price on every request.
- The timeout uses a thread join with a budget — crude, visible,
  and enforced by *us*, not by hoping the carrier's client library
  has sensible defaults. The doorman doesn't outsource the door.
- The same shape covers every aggregation integration I'm asked
  about: payment processors, geocoders, LLM providers, search
  backends. One adapter per source, one face for all outcomes,
  one core that reads like the requirements doc.

## Verdict

Two degraded carriers, one confused schema, one apocalypse — and
checkout answered correctly every time, with reasons preserved and
zero fear in the core. Confidence isn't the absence of suspicion;
it's suspicion spent once, at the door, by a professional.

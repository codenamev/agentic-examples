# Round 19 field notes — Soutaro Matsumoto holds a séance

*Built: `examples/type_seance.rb` — a plan with no annotations is
run once, every seam's value shape observed and transcribed to RBS;
the inferred signatures become a contract, and a poltergeist task
that changes its return type on a later run is caught by the ghost
of its own first answer.*

## What I built and why

Round 14 I exported RBS from declared contracts — types from
*intent*. The strange round asks for the other direction, the one
that sounds like a party trick and is actually half of how gradual
typing adoption works in practice: **types from observation.** A
program with no annotations still has types; they're just stored in
the runtime instead of a file. One sitting with a departed run
transcribes them:

```
def fetch:  (void) -> Array[String]
def parse:  (Array[String]) -> Array[Hash[Symbol, untyped]]
def score:  (Array[Hash[Symbol, untyped]]) -> Array[Integer]
def format: (Array[Integer]) -> String
```

Nobody wrote those. The plan's seams — `previous_output` crossing
from task to task — are natural observation points, and a
40-line medium (`shape_of`, recursing through arrays and hashes)
does what every runtime-type-collection tool does at heart. Note
the honest `untyped` in parse's hash values: qty is Integer, item
is String, so the medium declines to overclaim. Inference that
never says `untyped` is inference that's lying somewhere.

## The poltergeist, and the contagion

The inferred transcript then becomes a contract for future runs. A
second honest run conforms 4/4 — inference that rejects the very
behavior it was inferred from would be useless. Then the
poltergeist: a `score` that behaved on its first visit and returns
`Array[Float]` on its second. Caught — and here's the detail I
built the whole example for — **two seams are haunted, not one**:

```
SEAM HAUNTED: score  - promised -> Array[Integer], delivered -> Array[Float]
SEAM HAUNTED: format - promised (Array[Integer]) -> String,
              delivered (Array[Float]) -> String
```

The lie travels downstream wearing the caller's clothes: format's
*input* seam breaks through no fault of format's. This is exactly
how type errors present in Steep — the diagnostic appears where the
value lands, not only where it was minted — and seeing it happen
dynamically, between two runs of an unannotated plan, is the best
argument for signatures I know: they pin blame to the seam that
*minted* the wrong value.

## Notes

- What inference cannot give you is intent. The medium transcribed
  `Integer` because that's what score returned, not because score
  *meant* it — which is precisely why the Float is a haunting and
  not a wider union. Choosing between "tighten to what I saw" and
  "widen to what I might see" is a human judgment; the séance just
  puts the choice in front of you with evidence.
- Multiple sittings would improve the transcript (unions from
  varied inputs, optional keys from absent ones). One sitting is
  the honest minimum and the example says so.
- Pipeline to production: observe seams in staging via the journal,
  emit draft RBS, human review for intent, then Steep in CI. Every
  piece of that exists today; this example is the missing first
  step done in 110 lines.

## Verdict

One unannotated plan, four signatures nobody wrote, a poltergeist
caught by its own ghost, and blame that travels exactly the way
Steep says it should. Types are observations, formalized — and the
program was observing all along; it just needed a medium.

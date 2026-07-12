# Round 18 field notes — Andrew Kane trains the bard

*Built: `examples/markov_bard.rb` — an order-2 Markov chain trained
on commit messages, generating new ones, with the real product
bolted on top: an eval. Fluency, novelty (memorization measured and
reported), determinism. 40 lines of model, and the eval is longer.*

## What I built and why

Every gem I ship has the same secret: the model is the easy part.
Told to be creative, I built the smallest language model that can
still embarrass you — a word-level Markov chain, order 2, trained
on twenty commit messages — because at this size you can see the
*whole* problem, including the part production teams skip:

```
trained on 20 commit messages; auditioned 20 candidates:
  rejected as memorized: 2 (printed, not hidden - that's the eval)

tonight's reading, 'Changelog in Four Movements':
  1. test the retry budget to the client
  2. fix broken links in the journal
  3. remove dead code from the client
```

Those lines don't exist in the corpus. They're recombinations
through shared bigrams — the chain learned that "the retry budget"
and "to the client" both follow naturally from their contexts and
soldered them together. That's generation. And two candidates came
out as verbatim training lines — that's *memorization*, and the
example's whole personality is that it counts them and prints the
number. Every generative system, from this one to the
trillion-parameter ones, owes its users the same three receipts:

1. **Fluency** — every 3-gram in the output was learned, none
   invented. (For a Markov chain this holds by construction;
   asserting it anyway is what catches the refactor that breaks it
   next year.)
2. **Novelty** — no verbatim lines, no 6-word windows lifted.
   Memorization is measured and reported, not discovered by a
   lawyer.
3. **Determinism** — seeded sampling, so the same seed writes the
   same poetry in CI forever. An eval you can't rerun is a vibe.

## The plan did the boring ML honestly too

Corpus shards tokenized in parallel, one merge task assembling the
chain, candidates auditioned in bulk and *filtered* — the pipeline
shape of every real training-and-eval loop, minus the GPUs. The
audition-then-filter step is the one teams forget scales down: when
your generator sometimes memorizes, generating N and rejecting the
plagiarists isn't a hack, it's the architecture, and the rejection
rate belongs on the tin.

## Notes

- The corpus was *designed* for branching — shared bigrams across
  lines ("the journal", "the client", "dead code") are what give the
  chain junctions to recombine at. Data curation is model design;
  this is also true at every other scale.
- "test the scheduler" (a truncation that reads like a haiku) is a
  legitimately learned ending — lines ending in "the scheduler"
  exist, so STOP is a learned transition. Fluent, novel, and
  accidentally profound.
- Swap the corpus for your actual changelog and this generates
  plausible release notes drafts today. I'm not saying ship it. I'm
  saying the eval harness is already written.

## Verdict

Forty lines of model, three receipts, two plagiarists caught at the
door, four poems that never existed before tonight. Practical ML
was never about the model — it's about being able to say, with a
straight face and an exit code, what your generator just did.

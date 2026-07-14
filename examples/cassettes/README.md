# Cassettes: recorded live LLM runs

Each `.yml` here is a real recorded interaction between a `live_*`
example and an actual LLM, captured once via `bin/record <name>` and
replayed deterministically by every subsequent run - CI, the showcase,
and contributors without keys included.

House rules:

- Only commit cassettes produced by `bin/record` against a real model.
  Hand-written or stub-recorded cassettes would turn "a real captured
  run" into fiction - the one sin this catalog cannot afford.
- Tokens are scrubbed automatically (`<LLM_TOKEN>`, Authorization header
  dropped), but eyeball a new cassette once before committing.
- Re-record when an example's prompts change: stale cassettes fail
  replay loudly (VCR raises on unmatched requests) rather than lie.

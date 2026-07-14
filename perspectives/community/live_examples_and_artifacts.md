# Field notes — the live tier and the artifact pipeline

*Built: `examples/live_goal_planner.rb`, `examples/live_import_mapper.rb`,
`examples/status_board.rb`, `bin/record`, and the showcase's artifact
collector — one push.*

## What this shows and why

The catalog's standing rule — offline, deterministic, self-verifying —
was starting to hide the headline feature: agentic exists to run *AI*
agents. Every example stubbed the LLM with a lambda at the seam where
`execute_plan(agent_provider)` would build a real one, and no page said
so. Two additions close that gap without giving up the rule:

1. **The live tier.** `live_*` examples make real LLM calls through the
   full stack — `TaskPlanner#analyze_goal` turning a goal into tasks,
   `DefaultAgentProvider` building an `Agent` + `LlmClient` per spec,
   `Task#perform` enforcing a `TaskOutputSchemas` schema over the wire.
   VCR records the first run (`bin/record`, the only keyed step) and
   every later run replays the cassette: offline, keyless, deterministic,
   and still *real* — the bytes on the page came from a model once.
   The pipeline was proven end-to-end against a local OpenAI-compatible
   stub, then the stub cassettes were deleted: only genuine recordings
   may wear the "recorded live run" badge.

2. **Artifacts.** Output is not always text. Examples that produce
   files write them to `AGENTIC_ARTIFACTS_DIR`; the showcase collects
   the directory per run and renders images inline, everything else as
   downloads. `status_board.rb` sets the pattern: the plan is the
   factory, the files are the deliverable, and the referee *reopens the
   files* — re-adds the CSV, counts the SVG's bars — rather than trust
   the plan's word.

Same push, same spirit: five early examples that surveyed a `lib/` that
no longer exists here (they predate the repo split) now resolve the
installed gem via `Gem::Specification`, and every scanner gained an
empty-scan guard — a survey of nothing exits 1 instead of bragging
about NaN%.

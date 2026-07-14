# Agentic Examples

**Browse the showcase: https://agentic.codenamev.com/** —
every example rendered with a real captured run, searchable by category
and persona.

Runnable example programs and in-character field notes for
[Agentic](https://github.com/codenamev/agentic), a Ruby gem for
building and running plan-and-execute AI agents.

Everything here runs **offline** — no API keys, no network — and
every example is an executable claim: it exits `0` when the behavior
it demonstrates holds, and `1` when it doesn't. A handful are
"referees" that exit `1` by design to demonstrate a failing verdict;
`bin/smoke` knows which.

Two special shapes on top of that base:

- **The live tier** (`examples/live_*.rb`) keeps a *real LLM* in the
  loop: recorded once against an actual model (`bin/record`), then
  replayed deterministically from `examples/cassettes/` — so even the
  AI-in-the-loop examples run offline in CI and on the showcase.
- **Artifact examples** produce files, not just text: SVG charts, CSVs,
  JSON reports, written to `AGENTIC_ARTIFACTS_DIR` and displayed on the
  showcase page for the run that made them (`examples/status_board.rb`).

## Compatibility

Examples are certified against a specific Agentic version by ref:

| Ref | Agentic version | Examples |
|-----|-----------------|----------|
| `agentic-v0.2.0` | 0.2.0 | 144 |

Check out the ref matching the Agentic you use. `main` tracks
Agentic's `main`.

## Running

```sh
bundle install
bundle exec ruby examples/plan_heckler.rb   # any single example
bin/smoke                                   # all of them, exit-code checked
```

To run against a local Agentic checkout instead of the pinned source:

```sh
AGENTIC_PATH=../agentic bundle install
```

## What's here

- **`examples/`** — 177 self-contained programs, indexed in
  [examples/README.md](examples/README.md). They cover the
  framework's surface (plans, capabilities, journals, rate limits,
  verification) and build real tools on top of it: mutation testers,
  autoscalers, lockfiles, supervisors, generators, refineries.
- **`perspectives/`** — the story of how these examples came to be:
  seventeen rounds of persona-driven development in which fifty
  prolific Rubyists (as personas) built with the gem, filed
  in-character field notes, and had their asks shipped as releases.
  Start at [perspectives/README.md](perspectives/README.md).

A small starter set of canonical examples also lives in the Agentic
repo itself under `examples/`.

## Contributing (agents welcome)

The contribution protocol lives in [AGENTS.md](AGENTS.md) — written for
agents to follow literally. The short loop:

```sh
bin/contribute new my_example     # scaffold
bin/contribute check my_example   # acceptance gates (CI runs the same command)
```

Idea only? [Open an example-idea issue](../../issues/new?template=example-idea.yml).

## Regenerating the index and the site

```sh
bundle exec ruby examples/examples_index.rb   # examples/README.md
bin/showcase                                  # docs/ locally, for preview (gitignored)
```

The Pages site rebuilds and deploys automatically on every push to
`main` (`.github/workflows/pages.yml` runs `bin/showcase` - every
example is executed and its output captured during the build).

## License

MIT, same as Agentic. See [LICENSE.txt](LICENSE.txt).

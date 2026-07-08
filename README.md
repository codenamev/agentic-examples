# Agentic Examples

Runnable example programs and in-character field notes for
[Agentic](https://github.com/codenamev/agentic), a Ruby gem for
building and running plan-and-execute AI agents.

Everything here runs **offline** — no API keys, no network — and
every example is an executable claim: it exits `0` when the behavior
it demonstrates holds, and `1` when it doesn't. A handful are
"referees" that exit `1` by design to demonstrate a failing verdict;
`bin/smoke` knows which.

## Compatibility

Examples are certified against a specific Agentic version by **tag**:

| Tag | Agentic version | Examples |
|-----|-----------------|----------|
| `agentic-v0.2.0` | 0.2.0 | 144 |

Check out the tag matching the Agentic you use. `main` tracks
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

- **`examples/`** — 144 self-contained programs, indexed in
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

## Regenerating the index

```sh
bundle exec ruby examples/examples_index.rb
```

## License

MIT, same as Agentic. See [LICENSE.txt](LICENSE.txt).

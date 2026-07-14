# Agentic Examples

**Browse the showcase: https://codenamev.github.io/agentic-examples/** —
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

- **`examples/`** — 174 self-contained programs, indexed in
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
bin/showcase                                  # docs/ (the GitHub Pages site; maintainers, post-merge)
```

## License

MIT, same as Agentic. See [LICENSE.txt](LICENSE.txt).

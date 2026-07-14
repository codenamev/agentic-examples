# frozen_string_literal: true

source "https://rubygems.org"

# Point AGENTIC_PATH at a local checkout of codenamev/agentic to run
# the examples against work in progress; otherwise the pinned tag of
# this repo tells you which agentic these examples are certified for.
if (path = ENV["AGENTIC_PATH"])
  gem "agentic", path: path
else
  gem "agentic", github: "codenamev/agentic", branch: "main"
end

# The live tier: examples/live_*.rb make real LLM calls once (bin/record),
# then replay the recorded HTTP deterministically everywhere else - CI and
# the showcase never need a key.
gem "vcr", "~> 6.2"
gem "webmock", "~> 3.23"

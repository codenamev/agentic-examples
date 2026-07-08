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

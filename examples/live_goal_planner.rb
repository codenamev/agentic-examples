# frozen_string_literal: true

# Live Goal Planner: the step every offline example skips, run for real.
# You hand agentic a GOAL in plain language; TaskPlanner asks an LLM to
# break it into tasks - each with an agent spec (name, purpose,
# instructions) - and PlanOrchestrator then executes that generated plan
# with real agents built by DefaultAgentProvider, one LLM call per task.
# Nothing here is stubbed: the plan you watch being made is the plan
# that runs. Recorded once with a real key (bin/record), then replayed
# deterministically from examples/cassettes/ - CI never needs credentials.
#
#   bundle exec ruby examples/live_goal_planner.rb
#
# Replays offline from its cassette; exits 1 unless the LLM produced a
# plan of 2+ tasks with complete agent specs and every task executed to
# completion. Before the first recording it explains itself and exits 0.

require "bundler/setup"
require "agentic"
require "vcr"

Agentic.logger.level = :fatal

NAME = File.basename(__FILE__, ".rb")
CASSETTES = File.expand_path("cassettes", __dir__)
RECORDING = ENV["RECORD"] == "1"

unless RECORDING || File.exist?(File.join(CASSETTES, "#{NAME}.yml"))
  puts "LIVE GOAL PLANNER - not yet recorded"
  puts
  puts "  this example drives real LLM calls through the full stack:"
  puts "  goal -> TaskPlanner -> generated tasks -> real agents -> results."
  puts "  record it once (the only step that needs a key):"
  puts "    OPENAI_ACCESS_TOKEN=... bin/record #{NAME}"
  puts "  after that every run replays the recording, offline, byte-for-byte."
  exit 0
end

VCR.configure do |c|
  c.cassette_library_dir = CASSETTES
  c.hook_into :webmock
  c.filter_sensitive_data("<LLM_TOKEN>") { Agentic.configuration.access_token }
  c.before_record { |i| i.request.headers.delete("Authorization") }
  # match on path, not full uri: a cassette recorded against a local model
  # replays fine in CI, where the client points at the default endpoint
  c.default_cassette_options = {match_requests_on: [:method, :path]}
end

# replay needs no credentials - every byte of HTTP comes from the cassette
Agentic.configure { |c| c.access_token ||= "vcr-replay" } unless RECORDING

GOAL = "Write a launch-day smoke checklist for a small web app's checkout flow"

VCR.use_cassette(NAME, record: RECORDING ? :all : :none) do
  puts "LIVE GOAL PLANNER (goal -> plan -> agents -> results, no stubs)"
  puts
  puts "  goal: #{GOAL.inspect}"
  puts

  planner = Agentic::TaskPlanner.new(GOAL)
  planner.analyze_goal
  plan = planner.execution_plan

  puts "  the LLM broke that into #{plan.tasks.size} tasks:"
  plan.tasks.each_with_index do |t, i|
    puts "    #{i + 1}. #{t.description}"
    puts "       agent: #{t.agent.name} - #{t.agent.instructions.to_s.lines.first.to_s.strip[0, 70]}"
  end
  puts

  # concurrency 1 so replay order matches recording order exactly
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 1, retry_policy: {max_retries: 0, retryable_errors: []})
  tasks = plan.tasks.map { |defn| Agentic::Task.from_definition(defn) }
  tasks.each_with_index { |t, i| orchestrator.add_task(t, i.zero? ? [] : [tasks[i - 1]]) }
  result = orchestrator.execute_plan(Agentic::DefaultAgentProvider.new)

  puts "  then each task ran against a real agent (one LLM call apiece):"
  tasks.each do |t|
    line = t.output.to_s.gsub(/\s+/, " ").strip
    puts "    [#{t.status}] #{t.description[0, 50]}: #{line[0, 80]}#{"..." if line.size > 80}"
  end
  puts

  failures = []
  failures << "plan too thin (#{plan.tasks.size} tasks)" if plan.tasks.size < 2
  failures << "an agent spec came back incomplete" unless plan.tasks.all? { |t| t.agent.name && t.agent.instructions }
  failures << "plan status: #{result.status}" unless result.status == :completed
  failures << "a task produced no output" unless tasks.all? { |t| !t.output.to_s.strip.empty? }

  puts "  every line above came over the wire from a model: the plan, the"
  puts "  agent specs, and the outputs. the recording IS the proof - replay"
  puts "  it anywhere, keyless, and the same real run re-testifies."
  exit(failures.empty? ? 0 : 1)
end

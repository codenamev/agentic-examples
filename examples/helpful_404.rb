# frozen_string_literal: true

# The Helpful 404: every system has three doors where users arrive
# with a typo - the URL, the config file, and the CLI - and at all
# three the system is holding the complete list of correct answers
# at the exact moment it says "not found." Spending one Levenshtein
# pass there converts a dead end into a one-keystroke fix. This
# example wires the framework's own Suggestions engine into all
# three doors, and proves the discipline that makes suggestions
# trustworthy: the CONSERVATISM rule. Garbage gets silence, because
# a wrong suggestion is worse than none - it sends a confused user
# somewhere confidently.
#
#   bundle exec ruby examples/helpful_404.rb
#
# Runs offline; exits 1 unless every typo gets the right hint and
# every stranger gets honest silence.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

ROUTES = ["/users/:id", "/orders/:id", "/invoices", "/settings", "/health"].freeze
CONFIG_SCHEMA = ["max_retries", "timeout_ms", "pool_size", "log_level"].freeze
CLI_COMMANDS = ["status", "deploy", "rollback", "logs", "console"].freeze

# One engine, three doors. Each door normalizes its own shape, then
# asks the same question: closest valid name within the budget?
DOORS = {
  "router" => {
    candidates: ROUTES.map { |r| r.split("/")[1] },
    normalize: ->(input) { input.split("/")[1].to_s },
    render: ->(input, hit) { hit ? "404 #{input} - did you mean /#{hit}#{ROUTES.find { |r| r.include?(hit) }[/\/:\w+/]}?" : "404 #{input}" }
  },
  "config" => {
    candidates: CONFIG_SCHEMA,
    normalize: ->(input) { input },
    render: ->(input, hit) { hit ? "unknown key '#{input}' - did you mean '#{hit}'?" : "unknown key '#{input}'" }
  },
  "cli" => {
    candidates: CLI_COMMANDS,
    normalize: ->(input) { input },
    render: ->(input, hit) { hit ? "no command '#{input}' - did you mean '#{hit}'?" : "no command '#{input}'" }
  }
}.freeze

TRIALS = [
  {door: "router", input: "/userz/42", expect_hint: "users"},
  {door: "router", input: "/xyzzy", expect_hint: nil}, # a stranger; silence
  {door: "config", input: "max_retrys", expect_hint: "max_retries"},
  {door: "config", input: "databese_url", expect_hint: nil}, # not close to anything we have
  {door: "cli", input: "stauts", expect_hint: "status"},
  {door: "cli", input: "shipit", expect_hint: nil} # aspirational; silence
].freeze

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 3)
trial_tasks = TRIALS.map do |trial|
  task = Agentic::Task.new(description: "#{trial[:door]}: #{trial[:input]}", agent_spec: {"name" => trial[:door], "instructions" => "help"})
  orchestrator.add_task(task, agent: ->(_t) {
    door = DOORS[trial[:door]]
    hit = Agentic::Suggestions.suggest(door[:normalize].call(trial[:input]), door[:candidates])
    {message: door[:render].call(trial[:input], hit), hit: hit}
  })
  task
end
result = orchestrator.execute_plan

puts "THE HELPFUL 404 (the system was holding the answer key when it said not-found)"
puts
failures = []
TRIALS.each_with_index do |trial, i|
  outcome = result.task_result(trial_tasks[i].id).output
  status = (outcome[:hit]&.to_s == trial[:expect_hint]&.to_s) ? "ok" : "WRONG"
  failures << "#{trial[:door]} #{trial[:input]}: suggested #{outcome[:hit].inspect}, wanted #{trial[:expect_hint].inspect}" unless status == "ok"
  puts format("  %-8s %-14s -> %s", trial[:door], trial[:input], outcome[:message])
end
puts

hints_given = TRIALS.count { |t| t[:expect_hint] }
puts "  score: #{hints_given} typos rescued, #{TRIALS.size - hints_given} strangers given honest silence."
puts
puts "  three doors, one engine, one discipline. the engine is the"
puts "  framework's own Suggestions module - the same Levenshtein that"
puts "  fixes contract keys fixes URLs and subcommands, because a typo"
puts "  doesn't care what layer it's in. the discipline is conservatism:"
puts "  the threshold scales with word length, so 'stauts' finds 'status'"
puts "  but 'shipit' finds nothing - a wrong suggestion ships a confused"
puts "  user somewhere CONFIDENTLY, which is strictly worse than a plain"
puts "  404. and the reason this feature is so cheap that skipping it is"
puts "  a choice: at the moment any system says 'not found', it is"
puts "  HOLDING the complete list of things that exist - routes, schema"
puts "  keys, commands. the error message is a UI. spend the Levenshtein."
exit(failures.empty? ? 0 : 1)

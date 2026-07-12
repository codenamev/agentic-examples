# frozen_string_literal: true

# The Etude Machine: deliberate practice for plan-builders. An etude
# is a small broken plan, a hint, and a hidden test - you fix the
# plan until the test passes, exactly like an exercism exercise. But
# the machine holds ITSELF to the practice-room standard before any
# student arrives: every etude's broken form must FAIL the hidden
# test (an exercise that passes before you touch it teaches
# nothing), every etude must carry a model solution that PASSES
# (unsolvable exercises are hazing), and difficulty must climb one
# concept at a time - scales before songs.
#
#   bundle exec ruby examples/etude_machine.rb
#
# Runs offline; exits 1 unless every etude fails broken, passes
# solved, and the curriculum climbs monotonically.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

# Each etude: a builder that assembles the plan either :broken or
# :solved, a hidden test over the result, a hint, and the concepts
# the solution exercises (the difficulty score is their count)
ETUDES = [
  {
    title: "1. The Missing Thread",
    hint: "greet reads previous_output... from whom?",
    concepts: [:dependencies],
    test: ->(result, tasks) { result.task_result(tasks[:greet].id)&.output == "hello, world" },
    build: ->(mode) {
      orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 2)
      name = Agentic::Task.new(description: "fetch name", agent_spec: {"name" => "n", "instructions" => "w"})
      greet = Agentic::Task.new(description: "greet", agent_spec: {"name" => "g", "instructions" => "w"})
      orchestrator.add_task(name, agent: ->(_t) { "world" })
      deps = (mode == :solved) ? [name] : [] # the thread, missing
      orchestrator.add_task(greet, deps, agent: ->(t) { "hello, #{t.previous_output}" })
      [orchestrator, {name: name, greet: greet}]
    }
  },
  {
    title: "2. The Swapped Hats",
    hint: "each agent is wearing the other's job description",
    concepts: [:dependencies, :agents],
    test: ->(result, tasks) { result.task_result(tasks[:publish].id)&.output == "PUBLISHED: draft of 3 words" },
    build: ->(mode) {
      orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 2)
      write = Agentic::Task.new(description: "write", agent_spec: {"name" => "w", "instructions" => "w"})
      publish = Agentic::Task.new(description: "publish", agent_spec: {"name" => "p", "instructions" => "w"})
      writer = ->(_t) { "draft of 3 words" }
      publisher = ->(t) { "PUBLISHED: #{t.previous_output}" }
      first, second = (mode == :solved) ? [writer, publisher] : [publisher, writer]
      orchestrator.add_task(write, agent: first)
      orchestrator.add_task(publish, [write], agent: second)
      [orchestrator, {write: write, publish: publish}]
    }
  },
  {
    title: "3. The Stubborn Courier",
    hint: "the courier fails TRANSIENTLY; the plan gives up permanently. one policy line.",
    concepts: [:dependencies, :agents, :retry_policy],
    test: ->(result, tasks) { result.task_result(tasks[:deliver].id)&.output == "delivered on attempt 2" },
    build: ->(mode) {
      policy = (mode == :solved) ? {max_retries: 2, backoff_base: 0.005, retryable_errors: [Agentic::Errors::LlmRateLimitError]} : {max_retries: 0, retryable_errors: []}
      orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 1, retry_policy: policy)
      deliver = Agentic::Task.new(description: "deliver", agent_spec: {"name" => "d", "instructions" => "w"})
      attempts = 0
      orchestrator.add_task(deliver, agent: ->(_t) {
        attempts += 1
        raise Agentic::Errors::LlmRateLimitError, "dog at the gate" if attempts == 1
        "delivered on attempt #{attempts}"
      })
      [orchestrator, {deliver: deliver}]
    }
  }
].freeze

puts "THE ETUDE MACHINE (scales before songs)"
puts

failures = []
difficulties = []
ETUDES.each do |etude|
  broken_result, broken_tasks = etude[:build].call(:broken).then { |o, t| [o.execute_plan, t] }
  solved_result, solved_tasks = etude[:build].call(:solved).then { |o, t| [o.execute_plan, t] }
  fails_broken = !etude[:test].call(broken_result, broken_tasks)
  passes_solved = etude[:test].call(solved_result, solved_tasks)
  difficulties << etude[:concepts].size

  puts "  #{etude[:title]}  (concepts: #{etude[:concepts].join(", ")})"
  puts "     hint: #{etude[:hint]}"
  puts "     broken form fails the hidden test: #{fails_broken ? "yes (as an exercise must)" : "NO - free pass, worthless"}"
  puts "     model solution passes:             #{passes_solved ? "yes (solvable, not hazing)" : "NO - unsolvable"}"
  puts
  failures << "#{etude[:title]} gives a free pass" unless fails_broken
  failures << "#{etude[:title]} is unsolvable" unless passes_solved
end

failures << "curriculum difficulty not monotonic: #{difficulties.inspect}" unless difficulties.each_cons(2).all? { |a, b| a <= b }

puts "  curriculum: #{difficulties.join(" -> ")} concepts per etude - each adds exactly one."
puts
puts "  the machine holds itself to the practice-room standard: every"
puts "  broken form FAILS (an exercise that passes before you touch it"
puts "  teaches nothing but false confidence), every etude ships a model"
puts "  solution that PASSES (unsolvable exercises aren't rigor, they're"
puts "  hazing), and difficulty climbs one concept at a time - thread a"
puts "  dependency, then assign the right agent, then write a retry"
puts "  policy. that ordering is the actual pedagogy: practice is only"
puts "  deliberate when the next rung is exactly one reach away, and"
puts "  the feedback - a hidden test with an exit code - arrives in"
puts "  seconds, not in code review three weeks later. fluency in a"
puts "  framework is built the same way as fluency in anything: small"
puts "  pieces, immediate feedback, rising difficulty, no free passes."
exit(failures.empty? ? 0 : 1)

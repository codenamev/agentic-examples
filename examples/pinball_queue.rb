# frozen_string_literal: true

# The Pinball Queue: a job queue explained on a pinball table,
# because every retry policy I have ever shipped is already in the
# machine. Balls are jobs. Flippers are workers (two; the table is
# the concurrency limit). A DRAIN is a transient failure - and the
# BALL SAVE kicks it back automatically, which is all a retry is.
# TILT is the poison ball: you don't ball-save a tilt, you end the
# turn and put the ball in the trough (the dead letter office) where
# a human decides. And the scoreboard practices double-entry
# bookkeeping: every ball launched is a ball scored or a ball
# troughed. Pinball is exciting. Your job queue should not be.
#
#   bundle exec ruby examples/pinball_queue.rb
#
# Runs offline; exits 1 if any ball goes unaccounted.

require "bundler/setup"
require "agentic"
require "tmpdir"

Agentic.logger.level = :fatal

BALLS = [
  {name: "ball-1 (clean)", behavior: :clean, points: 5000},
  {name: "ball-2 (rattles the drain)", behavior: :drains_once, points: 12_000},
  {name: "ball-3 (clean)", behavior: :clean, points: 7000},
  {name: "ball-4 (TILT machine)", behavior: :tilt, points: 0},
  {name: "ball-5 (drains twice!)", behavior: :drains_twice, points: 25_000}
].freeze

journal = Agentic::ExecutionJournal.new(path: File.join(Dir.tmpdir, "agentic_pinball.jsonl"))
File.delete(journal.path) if File.exist?(journal.path)

orchestrator = Agentic::PlanOrchestrator.new(
  concurrency_limit: 2, # two flippers
  lifecycle_hooks: journal.lifecycle_hooks,
  retry_policy: {max_retries: 2, backoff_base: 0.005, retryable_errors: [Agentic::Errors::LlmRateLimitError]}
)

plays = Hash.new(0)
tasks = BALLS.to_h do |ball|
  task = Agentic::Task.new(description: ball[:name], agent_spec: {"name" => ball[:name], "instructions" => "play"})
  orchestrator.add_task(task, agent: ->(_t) {
    plays[ball[:name]] += 1
    case ball[:behavior]
    when :tilt
      # you do not ball-save a tilt; the turn is OVER
      raise Agentic::Errors::LlmAuthenticationError, "TILT - nudged the machine like it owed them money"
    when :drains_once
      raise Agentic::Errors::LlmRateLimitError, "center drain" if plays[ball[:name]] == 1
    when :drains_twice
      raise Agentic::Errors::LlmRateLimitError, "center drain, again" if plays[ball[:name]] <= 2
    end
    {points: ball[:points]}
  })
  [ball[:name], task]
end
result = orchestrator.execute_plan

puts "THE PINBALL QUEUE (pinball is exciting; your job queue should not be)"
puts
scored = 0
troughed = []
BALLS.each do |ball|
  task_result = result.task_result(tasks[ball[:name]].id)
  saves = plays[ball[:name]] - 1
  if task_result.successful?
    scored += task_result.output[:points]
    save_note = saves.positive? ? " after #{saves} ball save#{"s" if saves > 1}" : ""
    puts format("  %-28s %8d points%s", ball[:name], task_result.output[:points], save_note)
  else
    troughed << ball[:name]
    puts format("  %-28s %8s  -> the trough (dead letters): #{task_result.failure.message}", ball[:name], "TILT")
  end
end
puts
puts format("  FINAL SCORE: %d   balls launched: %d, scored: %d, in the trough: %d",
  scored, BALLS.size, BALLS.size - troughed.size, troughed.size)

# --- the referee: double-entry bookkeeping for balls -------------------------------
failures = []
failures << "a ball vanished" unless BALLS.size == (BALLS.size - troughed.size) + troughed.size && troughed == ["ball-4 (TILT machine)"]
failures << "the tilt was ball-saved (never retry a tilt)" unless plays["ball-4 (TILT machine)"] == 1
failures << "ball save #1 miscounted" unless plays["ball-2 (rattles the drain)"] == 2
failures << "ball save #2 miscounted" unless plays["ball-5 (drains twice!)"] == 3
failures << "score wrong" unless scored == 49_000
replayed = Agentic::ExecutionJournal.replay(path: journal.path)
drains = replayed.events.count { |e| e[:event] == "task_failed" && e[:error].to_s.include?("drain") }
failures << "instant replay disagrees (#{drains} drains on tape)" unless drains == 3

puts
puts "  referee: every ball accounted - 3 drains on the instant replay"
puts "  (the journal), each ball-saved by policy; the tilt was NOT saved,"
puts "  because tilts are non-retryable by decree and retrying one is how"
puts "  you tilt twice. this is the whole gospel of background jobs on"
puts "  one table: transient failures get automatic, bounded, backed-off"
puts "  retries (the ball save has a budget - drain a fourth time and"
puts "  you're done); poison gets a human (the trough is a QUEUE, not a"
puts "  void - someone reviews it after the game); and the scoreboard"
puts "  balances or the machine is broken. exciting things happen on the"
puts "  playfield so that nothing exciting ever happens to the ledger."
exit(failures.empty? ? 0 : 1)

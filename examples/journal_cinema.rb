# frozen_string_literal: true

# The Journal Cinema: an execution journal is a film negative. The
# run happened once, in real time, unwatched - then the negative
# sits in a JSONL can holding everything: who started, who failed,
# who came back, to the millisecond. This projector plays it back
# as a movie: same scenes, same order, same rhythm, compressed 4x
# for the theater. The referee checks the projection is FAITHFUL -
# every frame from the negative, in order, with the comeback arc
# intact. Films get edited; evidence doesn't.
#
#   bundle exec ruby examples/journal_cinema.rb
#
# Runs offline; a small drama is shot, then screened.

require "bundler/setup"
require "agentic"
require "time"
require "tmpdir"

Agentic.logger.level = :fatal

REEL = File.join(Dir.tmpdir, "agentic_cinema.jsonl")
File.delete(REEL) if File.exist?(REEL)

# --- act 1: the shoot (nobody watches the actual run; that's the point) ------------
journal = Agentic::ExecutionJournal.new(path: REEL)
orchestrator = Agentic::PlanOrchestrator.new(
  concurrency_limit: 2,
  lifecycle_hooks: journal.lifecycle_hooks,
  retry_policy: {max_retries: 1, backoff_base: 0.01, retryable_errors: [Agentic::Errors::LlmRateLimitError]}
)

compile_attempts = 0
coffee = Agentic::Task.new(description: "brew coffee", agent_spec: {"name" => "c", "instructions" => "w"})
compile = Agentic::Task.new(description: "compile assets", agent_spec: {"name" => "a", "instructions" => "w"})
deploy = Agentic::Task.new(description: "deploy", agent_spec: {"name" => "d", "instructions" => "w"})
bow = Agentic::Task.new(description: "take a bow", agent_spec: {"name" => "b", "instructions" => "w"})

orchestrator.add_task(coffee, agent: ->(_t) {
  sleep(0.03)
  "hot"
})
orchestrator.add_task(compile, agent: ->(_t) {
  compile_attempts += 1
  sleep(0.04)
  raise Agentic::Errors::LlmRateLimitError, "sass compiler mood" if compile_attempts == 1
  "compiled"
})
orchestrator.add_task(deploy, [compile], agent: ->(_t) {
  sleep(0.03)
  "shipped"
})
orchestrator.add_task(bow, [deploy, coffee], agent: ->(_t) { "applause" })
orchestrator.execute_plan

# --- act 2: the projection ----------------------------------------------------------
state = Agentic::ExecutionJournal.replay(path: REEL)
frames = state.events.select { |e| e[:event].start_with?("task_") }
times = frames.map { |e| Time.parse(e[:at]) }
negative_runtime = times.last - times.first
speed = 4.0

ICON = {"task_started" => "[ ACTION ]", "task_succeeded" => "[  CUT   ]", "task_failed" => "[ DRAMA! ]"}.freeze

puts "JOURNAL CINEMA presents: THE DEPLOY (runtime #{(negative_runtime * 1000).round}ms, projected at #{speed.to_i}x)"
puts
screened = []
projection_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
frames.each_with_index do |frame, i|
  sleep((times[i] - times[i - 1]) / speed) if i.positive?
  timecode = format("%05.0fms", (times[i] - times.first) * 1000)
  extra = (frame[:event] == "task_failed") ? " (#{frame[:error] || "retryable"} - but the negative says they came back)" : ""
  puts "    #{timecode}  #{ICON.fetch(frame[:event], "[ ????? ]")}  #{frame[:description]}#{extra}"
  screened << frame
end
projection_runtime = Process.clock_gettime(Process::CLOCK_MONOTONIC) - projection_started

puts
puts "    ~ fin ~   cast: #{[coffee, compile, deploy, bow].map(&:description).join(", ")}"
puts

# --- the referee: projection must be faithful to the negative -----------------------
failures = []
failures << "frames dropped or reordered" unless screened == frames
comeback = frames.each_index.any? do |i|
  frames[i][:event] == "task_failed" &&
    frames[(i + 1)..].any? { |f| f[:event] == "task_succeeded" && f[:description] == frames[i][:description] }
end
failures << "the comeback arc was cut" unless comeback
ratio = negative_runtime / projection_runtime
failures << "projection speed off (#{ratio.round(1)}x)" unless ratio.between?(speed * 0.5, speed * 2.0)

puts "  referee: #{screened.size}/#{frames.size} frames, order preserved, comeback arc intact,"
puts "           projected #{ratio.round(1)}x faster than life (asked for #{speed.to_i}x)"
puts
puts "  the journal was already a movie; it just needed a projector."
puts "  every run of every plan leaves this negative behind - who"
puts "  started, who failed, who came back, with millisecond timecodes -"
puts "  and playback is 30 lines: parse the timestamps, sleep the gaps"
puts "  scaled, print the scenes. incident review is watching last"
puts "  night's footage instead of interviewing witnesses. the compile"
puts "  failure isn't a log line, it's a SCENE, with a before and an"
puts "  after and a comeback - which is how the on-call human actually"
puts "  thinks about it. evidence with a playhead beats evidence with"
puts "  a grep prompt."
exit(failures.empty? ? 0 : 1)

# frozen_string_literal: true

# The Lightning Talks: five speakers, five minutes each, one GONG.
# The lightning talk is conference culture's greatest API: a hard
# timeout with applause. Speakers are tasks on a single-track stage
# (concurrency 1 - there is one podium); each presents slide by
# slide; and the gong is checked BETWEEN slides, because you can't
# interrupt a slide mid-sentence but you absolutely can decline to
# show the next one. Run over and the gong takes the mic, politely,
# in front of everyone. The session ends on time. Sessions END ON
# TIME. This is the entire technology.
#
#   bundle exec ruby examples/lightning_talks.rb
#
# Runs offline; exits 1 unless the rambler was gonged, the punctual
# finished, and the session respected the schedule.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

def mono = Process.clock_gettime(Process::CLOCK_MONOTONIC)

LIMIT = 0.05 # "five minutes" (conference seconds are small)
TALKS = [
  {speaker: "a_matz_uda", title: "Pagination Considered Wonderful", slides: 8, pace: 0.005},
  {speaker: "gem_hoarder", title: "My Gem Has 0 Downloads: a Love Story", slides: 9, pace: 0.005},
  {speaker: "dr_rambles", title: "A Brief History of Everything (pt. 1/40)", slides: 30, pace: 0.006},
  {speaker: "ci_arsonist", title: "How I Broke CI in 3 Languages", slides: 7, pace: 0.006},
  {speaker: "ractor_fan", title: "Waiting for Ractor: a Musical", slides: 8, pace: 0.005}
].freeze

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 1) # one podium
session_opened = mono
outcomes = {}
previous = nil
TALKS.each do |talk|
  task = Agentic::Task.new(description: talk[:title], agent_spec: {"name" => talk[:speaker], "instructions" => "present"})
  orchestrator.add_task(task, previous ? [previous] : [], agent: ->(_t) {
    started = mono
    shown = 0
    talk[:slides].times do
      break if mono - started >= LIMIT # THE GONG (checked between slides)
      sleep(talk[:pace])
      shown += 1
    end
    finished = mono - started
    gonged = shown < talk[:slides]
    outcomes[talk[:speaker]] = {shown: shown, of: talk[:slides], took: finished, gonged: gonged}
    gonged ? :gonged_with_dignity : :thunderous_applause
  })
  previous = task
end
orchestrator.execute_plan
session_length = mono - session_opened

puts "THE LIGHTNING TALKS (a hard timeout with applause)"
puts
puts format("  %-13s %-42s %-12s %s", "speaker", "talk", "slides", "outcome")
TALKS.each do |talk|
  o = outcomes[talk[:speaker]]
  outcome = o[:gonged] ? "GONG at #{(o[:took] * 1000).round}ms - slide #{o[:shown]}, mid-gesture" : "applause (#{(o[:took] * 1000).round}ms, under time)"
  puts format("  %-13s %-42s %-12s %s", talk[:speaker], talk[:title], "#{o[:shown]}/#{o[:of]}", outcome)
end
puts

# --- the referee: the schedule is sacred --------------------------------------------
failures = []
failures << "dr_rambles escaped the gong" unless outcomes["dr_rambles"][:gonged]
punctual = TALKS.reject { |t| t[:speaker] == "dr_rambles" }
failures << "a punctual speaker was gonged" if punctual.any? { |t| outcomes[t[:speaker]][:gonged] }
failures << "the gong was late" if outcomes.values.any? { |o| o[:took] > LIMIT + 0.02 }
budget = TALKS.size * LIMIT
failures << "session overran its worst case" if session_length > budget + 0.05

puts "  referee: session ran #{(session_length * 1000).round}ms against a worst-case budget of"
puts "  #{(budget * 1000).round}ms; every gong landed within one slide of the limit."
puts
puts "  the design notes are conference-tested: the timeout is checked at"
puts "  SLIDE boundaries, not mid-slide - cooperative cancellation at safe"
puts "  points, which is also how you cancel anything that holds state."
puts "  the gong is enforced by the STAGE, not the speaker (dr_rambles"
puts "  believed sincerely in slide 30). and the schedule composes: five"
puts "  bounded talks make one bounded session, which is why LT sessions"
puts "  are the only conference block that never runs late. a five-minute"
puts "  limit with a gong is worth forty minutes of speaker discipline -"
puts "  timeboxes beat promises, in talks and in tasks."
exit(failures.empty? ? 0 : 1)

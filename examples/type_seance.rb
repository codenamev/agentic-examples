# frozen_string_literal: true

# The Type Séance: this plan has no type annotations, but it HAD a
# run - and a run is a set of observations, and observations
# formalized are types. The séance sits with the departed execution,
# records the shape of every value that crossed every task seam, and
# transcribes what the spirits reveal as RBS. Then the strange part:
# the inferred signatures become a CONTRACT for the next run, and a
# poltergeist task - one that returns a different type the second
# time - is caught by the ghost of its own first answer. You said
# Array[Integer] in life. The medium remembers.
#
#   bundle exec ruby examples/type_seance.rb
#
# Runs offline; exits 1 unless the séance transcribes correctly and
# the poltergeist is caught at exactly the lying seam.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

# --- the medium: value shapes, transcribed to RBS-ish -------------------------------
def shape_of(value)
  case value
  when Array
    inner = value.map { |v| shape_of(v) }.uniq
    (inner.size == 1) ? "Array[#{inner.first}]" : "Array[untyped]"
  when Hash
    keys = value.keys.map { |k| shape_of(k) }.uniq
    vals = value.values.map { |v| shape_of(v) }.uniq
    "Hash[#{(keys.size == 1) ? keys.first : "untyped"}, #{(vals.size == 1) ? vals.first : "untyped"}]"
  else value.class.name
  end
end

# One sitting: run the plan, observe every seam, return the transcript
def hold_seance(score_agent)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 1)
  observed = {}
  agents = {
    "fetch" => ->(_in) { ["7 lamps", "3 rugs", "9 clocks"] },
    "parse" => ->(lines) { lines.map { |l| {qty: l.to_i, item: l.split.last} } },
    "score" => score_agent,
    "format" => ->(scores) { "total: #{scores.sum}" }
  }
  previous = nil
  agents.each do |name, fn|
    task = Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "w"})
    orchestrator.add_task(task, previous ? [previous] : [], agent: ->(t) {
      input = t.previous_output
      output = fn.call(input)
      observed[name] = {in: input.nil? ? "void" : shape_of(input), out: shape_of(output)}
      output
    })
    previous = task
  end
  orchestrator.execute_plan
  observed
end

honest_score = ->(rows) { rows.map { |r| r[:qty] * 10 } }
poltergeist_visits = 0
poltergeist_score = ->(rows) {
  poltergeist_visits += 1
  (poltergeist_visits == 1) ? rows.map { |r| r[:qty] * 10 } : rows.map { |r| r[:qty] * 10.0 } # honest in life...
}

puts "THE TYPE SEANCE (types are observations, formalized; the medium remembers)"
puts

# --- sitting one: infer RBS from the honest run --------------------------------------
transcript = hold_seance(honest_score)
puts "  the sitting: one run observed at every seam, transcribed to RBS:"
transcript.each { |name, sig| puts "    def #{name}: (#{sig[:in]}) -> #{sig[:out]}" }
puts

# --- sitting two: the contract holds the honest, catches the poltergeist -------------
honest_again = hold_seance(honest_score)
conform = transcript.keys.select { |k| honest_again[k] == transcript[k] }
puts "  second honest run against the inferred contract: #{conform.size}/#{transcript.size} seams conform"

haunted_first = hold_seance(poltergeist_score) # visit 1: behaves
haunted_second = hold_seance(poltergeist_score) # visit 2: lies
violations = transcript.keys.reject { |k| haunted_second[k] == transcript[k] }
puts
puts "  then the poltergeist: a score task that was honest on its first"
puts "  visit (#{(haunted_first["score"] == transcript["score"]) ? "conformed" : "?!"}) and changed its return type on the second:"
violations.each do |name|
  puts "    SEAM HAUNTED: #{name} - promised (#{transcript[name][:in]}) -> #{transcript[name][:out]},"
  puts "                  delivered (#{haunted_second[name][:in]}) -> #{haunted_second[name][:out]}"
end
puts

failures = []
failures << "inference wrong" unless transcript["parse"] == {in: "Array[String]", out: "Array[Hash[Symbol, untyped]]"}
failures << "honest run failed its own ghost" unless conform.size == transcript.size
failures << "poltergeist not caught, or caught wrongly" unless violations.include?("score") && violations.include?("format")
failures << "score's lie mislabeled" unless haunted_second["score"][:out] == "Array[Float]" && transcript["score"][:out] == "Array[Integer]"

puts "  gradual typing's whole wager, demonstrated seance-style: you do"
puts "  not have to WRITE the types - the program already knows them, at"
puts "  runtime, at every seam, and one observed run transcribes to RBS"
puts "  for free. what inference cannot give you is INTENT: the medium"
puts "  transcribed Integer because that's what score returned, not"
puts "  because score MEANT it - which is exactly why the poltergeist's"
puts "  Float is caught as a haunting rather than accepted as a wider"
puts "  union. note the contagion: score's lie condemned format's seam"
puts "  too (its INPUT shape changed) - type errors travel downstream"
puts "  wearing the caller's clothes, in seances as in Steep. observe"
puts "  first, formalize second, verify forever."
exit(failures.empty? ? 0 : 1)

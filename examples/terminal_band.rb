# frozen_string_literal: true

# The Terminal Band: a one-computer band where every instrument is a
# task. Four players compose their parts IN PARALLEL (they've played
# together for years; the chord chart is the only coordination), a
# mixer task fans them in by name, and then the part every real band
# needs: a harmony referee that checks every tick for dissonance and
# names the player responsible. This band once had a theremin. Once.
#
#   bundle exec ruby examples/terminal_band.rb
#
# Runs offline; exits 1 unless the final mix is consonant AND the
# referee correctly identified whom to fire.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

NOTE_NAMES = %w[C C# D D# E F F# G G# A A# B].freeze
CHART = [[0, 4, 7], [5, 9, 0], [7, 11, 2], [0, 4, 7]].freeze # I-IV-V-I in C, as pitch classes
TICKS = 16
DISSONANT = [1, 2, 6, 10, 11].freeze # the intervals that get you fired

def name_of(pitch) = pitch ? NOTE_NAMES[pitch % 12] : "."

def chord_at(tick) = CHART[tick / 4]

# --- the players (each composes alone; the chart keeps them honest) ----------------
PLAYERS = {
  "bass" => ->(_t) { TICKS.times.map { |i| chord_at(i)[0] } },                       # roots, always roots
  "melody" => ->(_t) { TICKS.times.map { |i| chord_at(i)[i % 3] } },                 # arpeggios, feeling fancy
  "harmony" => ->(_t) { TICKS.times.map { |i| chord_at(i)[(i + 1) % 3] } },          # a chord tone above
  "theremin" => ->(_t) { TICKS.times.map { |i| (i % 4 == 3) ? chord_at(i)[0] + 6 : nil } } # "it's called ART"
}.freeze

def band_plays(roster)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 4)
  tracks = roster.to_h do |name|
    task = Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "play"})
    orchestrator.add_task(task, agent: PLAYERS[name])
    [name, task]
  end
  mixer = Agentic::Task.new(description: "mixer", agent_spec: {"name" => "mixer", "instructions" => "mix"})
  orchestrator.add_task(mixer, needs: tracks.transform_values(&:itself), agent: ->(t) {
    roster.to_h { |name| [name, t.needs.public_send(name)] }
  })
  orchestrator.execute_plan.task_result(mixer.id).output
end

# The referee: flag every dissonant tick, then find the one player
# whose silence resolves ALL of them - that's who gets the phone call
def referee(mix)
  clashes = TICKS.times.select do |i|
    sounding = mix.values.map { |part| part[i] }.compact.map { |p| p % 12 }.uniq
    sounding.combination(2).any? { |a, b| DISSONANT.include?((a - b) % 12) || DISSONANT.include?((b - a) % 12) }
  end
  return [clashes, nil] if clashes.empty?
  culprit = mix.keys.find do |name|
    rest = mix.reject { |k, _| k == name }
    clashes.none? do |i|
      sounding = rest.values.map { |part| part[i] }.compact.map { |p| p % 12 }.uniq
      sounding.combination(2).any? { |a, b| DISSONANT.include?((a - b) % 12) || DISSONANT.include?((b - a) % 12) }
    end
  end
  [clashes, culprit]
end

def print_tracker(mix)
  puts "    tick  #{mix.keys.map { |k| k[0, 8].ljust(8) }.join}"
  TICKS.times do |i|
    puts "    %4d  %s" % [i, mix.keys.map { |k| name_of(mix[k][i]).ljust(8) }.join]
  end
end

puts "THE TERMINAL BAND (four players, one chart, zero rehearsals)"
puts

mix = band_plays(PLAYERS.keys)
clashes, culprit = referee(mix)
puts "  set one, with the full lineup:"
print_tracker(mix)
puts
puts "  referee: dissonance at ticks #{clashes.join(", ")} - and removing only"
puts "  #{culprit.inspect} resolves every one of them. it's not you, theremin,"
puts "  it's your tritones. (it's also you.)"
puts

fired_correctly = (culprit == "theremin")
mix2 = band_plays(PLAYERS.keys - [culprit])
clashes2, = referee(mix2)
puts "  set two, as a trio:"
print_tracker(mix2)
puts
puts "  referee: #{clashes2.empty? ? "sixteen ticks, zero dissonance - the band is TIGHT" : "STILL dissonant at #{clashes2.join(", ")}"}"
puts
puts "  the joke is load-bearing: the players composed in PARALLEL with"
puts "  no shared state but the chord chart - the same trick as any"
puts "  fan-out plan, where the contract (I-IV-V-I) replaces coordination."
puts "  the mixer read every part BY NAME (needs:), and the referee is a"
puts "  falsifiable claim about the combined output, per tick, with BLAME"
puts "  ATTRIBUTION - remove one input at a time until the property"
puts "  holds, which is bisection wearing a bow tie. also we fired a"
puts "  theremin over math. extremely our band."
exit((fired_correctly && clashes2.empty? && clashes.any?) ? 0 : 1)

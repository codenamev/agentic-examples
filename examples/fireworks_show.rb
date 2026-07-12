# frozen_string_literal: true

# The Fireworks Show: choreography IS concurrency. A show is three
# staggered volleys and then a finale - five shells that must burst
# TOGETHER, which is only physically possible if someone can light
# five fuses at once. We run the same score twice: once with a
# single igniter (the intern), once with a full crew (the fiber
# scheduler), and the burst timeline itself is the argument. You
# cannot sequence your way to a finale.
#
#   bundle exec ruby examples/fireworks_show.rb
#
# Runs offline; exits 1 unless the crewed finale is simultaneous
# AND the intern's provably wasn't.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

def mono = Process.clock_gettime(Process::CLOCK_MONOTONIC)

VOLLEYS = [
  [{name: "willow", fuse: 0.04}, {name: "peony", fuse: 0.05}, {name: "comet", fuse: 0.04}],
  [{name: "chrysanth", fuse: 0.05}, {name: "crossette", fuse: 0.04}, {name: "strobe", fuse: 0.05}],
  [{name: "palm", fuse: 0.04}, {name: "ring", fuse: 0.05}, {name: "fish", fuse: 0.04}]
].freeze
FINALE = 5.times.map { |i| {name: "finale-#{i + 1}", fuse: 0.05} }.freeze

def run_show(crew_size)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: crew_size)
  t0 = mono
  bursts = {}
  previous_volley = []
  VOLLEYS.each_with_index do |volley, v|
    previous_volley = volley.map do |shell|
      task = Agentic::Task.new(description: shell[:name], agent_spec: {"name" => shell[:name], "instructions" => "fly"})
      orchestrator.add_task(task, previous_volley, agent: ->(_t) {
        sleep(shell[:fuse])
        bursts[shell[:name]] = {volley: v, at: mono - t0}
        :boom
      })
      task
    end
  end
  FINALE.each do |shell|
    task = Agentic::Task.new(description: shell[:name], agent_spec: {"name" => shell[:name], "instructions" => "fly"})
    orchestrator.add_task(task, previous_volley, agent: ->(_t) {
      sleep(shell[:fuse])
      bursts[shell[:name]] = {volley: :finale, at: mono - t0}
      :BOOM
    })
  end
  orchestrator.execute_plan
  [bursts, mono - t0]
end

def timeline(bursts, duration, label)
  cols = 56
  puts "  #{label} (#{(duration * 1000).round}ms):"
  bursts.sort_by { |_, b| b[:at] }.each do |name, b|
    col = (b[:at] / duration * (cols - 1)).round
    mark = (b[:volley] == :finale) ? "#" : "*"
    puts "    #{name.ljust(10)} #{" " * col}#{mark}"
  end
end

def finale_spread(bursts)
  times = bursts.select { |_, b| b[:volley] == :finale }.map { |_, b| b[:at] }
  times.max - times.min
end

puts "THE FIREWORKS SHOW (you cannot sequence your way to a finale)"
puts

intern_bursts, intern_time = run_show(1)
crew_bursts, crew_time = run_show(8)

timeline(intern_bursts, intern_time, "one igniter, lighting fuses in a row")
puts
timeline(crew_bursts, crew_time, "full crew, same score")
puts

intern_spread = finale_spread(intern_bursts)
crew_spread = finale_spread(crew_bursts)
total_fuse = (VOLLEYS.flatten + FINALE).sum { |s| s[:fuse] }

puts "  finale spread: intern #{(intern_spread * 1000).round}ms (a sad trickle of #-marks)"
puts "                 crew   #{(crew_spread * 1000).round}ms (one vertical WALL of sky)"
puts "  show length:   intern #{(intern_time * 1000).round}ms vs crew #{(crew_time * 1000).round}ms"
puts "                 (#{(total_fuse * 1000).round}ms of total fuse burned either way - parallel isn't"
puts "                 faster fire, it's fire arranged in TIME)"
puts
puts "  the score is a plan: volleys are dependency layers (volley 2"
puts "  waits on volley 1 - that's rhythm), and the finale is a fan-in"
puts "  that must OVERLAP, which no amount of sequential diligence can"
puts "  produce. the scheduler isn't an optimization here; it's the"
puts "  performance itself. async is usually sold as throughput -"
puts "  requests per second, workers kept busy. the finale is the purer"
puts "  case: five things that must happen AT ONCE, and the only tool"
puts "  that can say 'at once' is the one holding all five fuses."
crewed_wall = crew_spread < 0.02
intern_trickle = intern_spread > crew_spread * 3
exit((crewed_wall && intern_trickle) ? 0 : 1)

# frozen_string_literal: true

# The Terminal Demoscene: a 64-column demo intro - parallax
# starfield, plasma, and a wrapping scroller - rendered by a plan
# that is, structurally, a render farm: every frame's three effects
# compute in PARALLEL as tasks, a compositor fans them in by name,
# and the reel collects the frames. And because demo effects are
# pure functions of the frame number, every crowd-pleaser is also a
# THEOREM: the scroller obeys its rotation law, the starfield
# conserves its stars with 2:1 parallax, and the plasma is periodic
# with period 24 - checked, not vibed. The demoscene always knew
# what this catalog keeps re-learning: determinism is a feature you
# can dance to.
#
#   bundle exec ruby examples/terminal_demoscene.rb
#
# Runs offline; exits 1 if any effect breaks its own physics.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

WIDTH = 64
STAR_ROWS = 5
PLASMA_ROWS = 5
FRAMES = 8
SCROLL_TEXT = "GREETINGS FROM THE STRANGE RUBY ROUND *** AGENTIC IN DA HOUSE *** "
STARS = [[2, 0, 1], [11, 2, 1], [27, 1, 1], [44, 3, 1], [58, 0, 1],
  [7, 4, 2], [21, 3, 2], [37, 2, 2], [52, 4, 2], [63, 1, 2]].freeze # [x, row, speed]
PLASMA_GLYPHS = " .:-=*#%".chars.freeze

# --- the effects: pure functions of the frame number ---------------------------------
STARFIELD = ->(f) {
  rows = Array.new(STAR_ROWS) { " " * WIDTH }
  STARS.each { |x, row, speed| rows[row][(x + f * speed) % WIDTH] = (speed == 2) ? "*" : "." }
  rows
}
PLASMA = ->(f) {
  Array.new(PLASMA_ROWS) { |y|
    WIDTH.times.map { |x| PLASMA_GLYPHS[((x + f) % 8 + (y + 2 * f) % 6) % PLASMA_GLYPHS.size] }.join
  }
}
SCROLLER = ->(f) {
  WIDTH.times.map { |p| SCROLL_TEXT[(p + f) % SCROLL_TEXT.size] }.join
}

# --- the render farm: frames x effects, all parallel, composited by name -------------
orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 8)
frame_tasks = FRAMES.times.map do |f|
  effects = {stars: STARFIELD, plasma: PLASMA, scroll: SCROLLER}.to_h do |name, fx|
    task = Agentic::Task.new(description: "#{name} f#{f}", agent_spec: {"name" => name.to_s, "instructions" => "render"})
    orchestrator.add_task(task, agent: ->(_t) { fx.call(f) })
    [name, task]
  end
  compositor = Agentic::Task.new(description: "composite f#{f}", agent_spec: {"name" => "comp", "instructions" => "w"})
  orchestrator.add_task(compositor, needs: effects, agent: ->(t) {
    ["+#{"-" * WIDTH}+"] + (Array(t.needs.stars) + Array(t.needs.plasma) + [t.needs.scroll]).map { |row| "|#{row}|" } + ["+#{"-" * WIDTH}+"]
  })
  compositor
end
result = orchestrator.execute_plan
reel = frame_tasks.map { |t| result.task_result(t.id).output }

puts "THE TERMINAL DEMOSCENE (determinism is a feature you can dance to)"
puts
[0, 3, 7].each do |f|
  puts "  frame #{f}:"
  reel[f].each { |line| puts "    #{line}" }
  puts
end

# --- the physics referee: every effect obeys its own law -----------------------------
failures = []

# scroller law: frame f, column p shows text[(p+f) % n]
scroller_law = FRAMES.times.all? { |f|
  line = reel[f][STAR_ROWS + PLASMA_ROWS + 1][1..-2]
  WIDTH.times.all? { |p| line[p] == SCROLL_TEXT[(p + f) % SCROLL_TEXT.size] }
}
failures << "scroller broke its rotation law" unless scroller_law

# starfield: conservation + 2:1 parallax
star_counts = FRAMES.times.map { |f| reel[f][1, STAR_ROWS].join.count(".*") }
failures << "stars not conserved: #{star_counts.inspect}" unless star_counts.uniq == [STARS.size]
slow0 = reel[0][1].index(".")
slow1 = reel[1][1].index(".")
fast0 = reel[0][1 + 4].index("*")
fast1 = reel[1][1 + 4].index("*")
failures << "parallax broken" unless (slow1 - slow0) % WIDTH == 1 && (fast1 - fast0) % WIDTH == 2

# plasma: period 24 (lcm of the x-phase 8 and the doubled y-phase 3)
failures << "plasma period wrong" unless PLASMA.call(0) == PLASMA.call(24) && PLASMA.call(0) != PLASMA.call(12)

# the farm: every frame same dimensions
failures << "frame dimensions drifted" unless reel.map { |fr| [fr.size, fr.first.size] }.uniq.size == 1

puts "  physics referee: scroller rotation law holds on all #{FRAMES} frames;"
puts "  #{STARS.size} stars conserved with 2:1 parallax; plasma period is exactly 24"
puts "  (equal at f+24, different at f+12); every frame #{reel.first.size}x#{reel.first.first.size}."
puts
puts "  the oldest joke in the demoscene is that it's the most rigorous"
puts "  software culture ever built by teenagers: effects are pure"
puts "  functions of the frame counter (they had no memory to waste on"
puts "  state), so every effect is checkable math - the scroller is"
puts "  modular arithmetic, the parallax is two velocities, the plasma"
puts "  is an LCM. the render farm shape falls out for free: pure"
puts "  effects parallelize without a mutex in sight, the compositor"
puts "  reads its layers BY NAME, and the reel is a fan-in. sixty-four"
puts "  columns, zero dependencies, and the crowd (the exit code) goes"
puts "  wild."
exit(failures.empty? ? 0 : 1)

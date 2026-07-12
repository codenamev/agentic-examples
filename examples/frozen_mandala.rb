# frozen_string_literal: true

# The Frozen Mandala: generative art with a purity contract. Eight
# painter tasks each paint one sector of a mandala IN PARALLEL from
# the same frozen inputs - a seed, a palette, a rule. Purity buys
# two properties you can frame on a wall: SYMMETRY (every sector
# identical, because identical inputs through a pure function give
# identical outputs - the eightfold pattern is referential
# transparency you can look at) and REPRODUCIBILITY (same seed,
# same mandala, byte for byte, forever). Then one painter gets
# "inspired", reaches for ambient randomness, and both properties
# shatter on camera. Freeze your inputs; the art is the proof.
#
#   bundle exec ruby examples/frozen_mandala.rb
#
# Runs offline; exits 1 unless purity is provably load-bearing.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

SECTORS = 8
BUCKETS = 12 # angular resolution within a sector
RADII = 10
GLYPHS = [" ", ".", "+", "o", "@"].freeze

# The one true brush: a pure function of (radius, local angle, seed)
PURE_BRUSH = ->(r, a, seed) {
  v = (r * r + a * (a + 3) + seed * 7) % 9
  (v < 4) ? GLYPHS[1 + ((r + a + seed) % 4)] : nil
}

# The inspired brush: reads the room (the room is entropy)
WILD_BRUSH = ->(r, a, _seed) {
  rng = Random.new # no seed. it's called FEELING, look it up
  (rng.rand < 0.4) ? GLYPHS[1 + rng.rand(4)] : nil
}

def paint_mandala(seed, brushes)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 8)
  painters = SECTORS.times.map do |s|
    task = Agentic::Task.new(description: "sector #{s}", agent_spec: {"name" => "painter #{s}", "instructions" => "paint"})
    orchestrator.add_task(task, agent: ->(_t) {
      (0...BUCKETS).map { |a| (0...RADII).map { |r| brushes[s].call(r, a, seed) } }
    })
    task
  end
  result = orchestrator.execute_plan
  painters.map { |t| result.task_result(t.id).output }
end

def render(sectors)
  size = RADII * 2 + 1
  grid = Array.new(size) { Array.new(size, " ") }
  (0...size).each do |y|
    (0...size).each do |x|
      dx = x - RADII
      dy = y - RADII
      r = Math.sqrt(dx * dx + dy * dy).round
      next if r >= RADII
      angle = (Math.atan2(dy, dx) + Math::PI) / (2 * Math::PI) # 0..1
      sector = [(angle * SECTORS).floor, SECTORS - 1].min
      local = [(angle * SECTORS % 1 * BUCKETS).floor, BUCKETS - 1].min
      grid[y][x] = sectors[sector][local][r] || " "
    end
  end
  grid.map { |row| "  " + row.join.center(size * 2) }.join("\n")
end

puts "THE FROZEN MANDALA (referential transparency you can look at)"
puts

pure_brushes = Array.new(SECTORS) { PURE_BRUSH }
first = paint_mandala(42, pure_brushes)
second = paint_mandala(42, pure_brushes)
puts render(first)
puts

symmetric = first.uniq.size == 1
reproducible = first == second
puts "  eight painters, frozen inputs (seed 42):"
puts "    symmetry:        #{symmetric ? "all 8 sectors identical - the pattern IS the purity" : "BROKEN"}"
puts "    reproducibility: #{reproducible ? "two runs, byte-identical - same seed, same art, forever" : "BROKEN"}"
puts

wild_brushes = pure_brushes.dup
wild_brushes[3] = WILD_BRUSH # painter 3 has been to an art retreat
wild_a = paint_mandala(42, wild_brushes)
wild_b = paint_mandala(42, wild_brushes)
wild_symmetric = wild_a.uniq.size == 1
wild_reproducible = wild_a == wild_b
odd_sectors = wild_a.each_index.reject { |i| wild_a[i] == wild_a.first }
puts "  then painter 3 discovers ambient entropy:"
puts "    symmetry:        #{wild_symmetric ? "held (suspicious)" : "broken - sector(s) #{odd_sectors.inspect} no longer match"}"
puts "    reproducibility: #{wild_reproducible ? "held (very suspicious)" : "broken - the same seed painted two different mandalas"}"
puts
puts "  the mandala is a pure function's self-portrait. eightfold"
puts "  symmetry isn't drawn - it's ENTAILED: eight tasks, same frozen"
puts "  inputs, same pure brush, therefore the same sector eight times,"
puts "  no coordination required (the painters never spoke). and"
puts "  reproducibility is the same theorem run twice. one impure"
puts "  painter - a single Random.new in one lambda - destroyed both"
puts "  properties at once, which is the lesson: purity isn't a style"
puts "  preference, it's the entire load-bearing structure, and art is"
puts "  a domain where you can SEE the structure fail. freeze your"
puts "  inputs. sign your seeds. regression-test your beauty."
exit((symmetric && reproducible && !wild_symmetric && !wild_reproducible) ? 0 : 1)

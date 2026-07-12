# frozen_string_literal: true

# The ASCII Darkroom: a photo pipeline where the photos are made of
# characters and the chemistry is arithmetic. One NEGATIVE comes in;
# the enlarger develops it into a print; then three derivative baths
# run in PARALLEL off the same developed print - high-contrast,
# thumbnail, vignette - and everything is promoted to the store
# directory as real files. The darkroom rules are the referee:
# derivatives never touch the negative (checksummed), inversion is
# an involution (develop the developed print and you get your
# negative back, exactly), and the thumbnail had better actually be
# smaller. Every upload gem is a darkroom with worse lighting.
#
#   bundle exec ruby examples/ascii_darkroom.rb
#
# Runs offline; exits 1 if any darkroom rule is violated.

require "bundler/setup"
require "agentic"
require "digest"
require "tmpdir"

Agentic.logger.level = :fatal

SHADES = " .:-=+*#%@".chars.freeze # intensity 0..9
W = 36
H = 14

# The negative, exposed procedurally: a moon over mountains (inverted, as negatives are)
NEGATIVE = H.times.map { |y|
  W.times.map { |x|
    moon = (Math.sqrt((x - 27)**2 + ((y - 3) * 2)**2) < 3.2) ? 9 : 0
    ridge = (y > 7 + Math.sin(x / 3.5) * 2) ? 7 : 0
    sky = [(H - y) / 3, 2].min
    9 - [moon, ridge, sky].max # invert: it's a negative
  }
}.freeze

def show(pixels, indent: 4)
  pixels.map { |row| " " * indent + row.map { |v| SHADES[v.clamp(0, 9)] }.join }.join("\n")
end

INVERT = ->(px) { px.map { |row| row.map { |v| 9 - v } } }
CONTRAST = ->(px) { px.map { |row| row.map { |v| (v < 5) ? [v - 2, 0].max : [v + 2, 9].min } } }
THUMBNAIL = ->(px) {
  (px.size / 2).times.map { |y|
    (px.first.size / 2).times.map { |x|
      (px[y * 2][x * 2] + px[y * 2][x * 2 + 1] + px[y * 2 + 1][x * 2] + px[y * 2 + 1][x * 2 + 1]) / 4
    }
  }
}
VIGNETTE = ->(px) {
  h = px.size
  w = px.first.size
  px.each_with_index.map { |row, y|
    row.each_with_index.map { |v, x|
      edge = [x, y, w - 1 - x, h - 1 - y].min
      (edge < 3) ? [v - (3 - edge) * 2, 0].max : v
    }
  }
}

store = Dir.mktmpdir("darkroom_store")
negative_checksum = Digest::SHA256.hexdigest(NEGATIVE.inspect)

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 3)
develop = Agentic::Task.new(description: "develop", agent_spec: {"name" => "enlarger", "instructions" => "develop"})
orchestrator.add_task(develop, agent: ->(_t) { INVERT.call(NEGATIVE) })

baths = {"contrast" => CONTRAST, "thumbnail" => THUMBNAIL, "vignette" => VIGNETTE}
derivative_tasks = baths.to_h do |name, chemistry|
  task = Agentic::Task.new(description: name, agent_spec: {"name" => name, "instructions" => "bathe"})
  orchestrator.add_task(task, [develop], agent: ->(t) {
    derivative = chemistry.call(t.previous_output)
    File.write(File.join(store, "#{name}.txt"), show(derivative, indent: 0))
    derivative
  })
  [name, task]
end
result = orchestrator.execute_plan

print_out = result.task_result(develop.id).output
thumb = result.task_result(derivative_tasks["thumbnail"].id).output

puts "THE ASCII DARKROOM (every upload gem is a darkroom with worse lighting)"
puts
puts "  the negative that came in:          ...and the developed print:"
NEGATIVE.each_index do |y|
  puts "    #{NEGATIVE[y].map { |v| SHADES[v] }.join}#{show([print_out[y]], indent: 4)}"
end
puts
puts "  the thumbnail derivative (#{thumb.first.size}x#{thumb.size}, from #{W}x#{H}):"
puts show(thumb)
puts

# --- the darkroom rules ---------------------------------------------------------------
failures = []
failures << "the NEGATIVE was touched" unless Digest::SHA256.hexdigest(NEGATIVE.inspect) == negative_checksum
failures << "inversion is not an involution" unless INVERT.call(print_out) == NEGATIVE
failures << "thumbnail dimensions wrong" unless thumb.size == H / 2 && thumb.first.size == W / 2
missing = baths.keys.reject { |name| File.exist?(File.join(store, "#{name}.txt")) }
failures << "derivatives not promoted: #{missing}" if missing.any?
failures << "a bath changed the print's dimensions" unless [result.task_result(derivative_tasks["contrast"].id).output,
  result.task_result(derivative_tasks["vignette"].id).output].all? { |d| d.size == H && d.first.size == W }

puts "  darkroom rules: negative untouched (checksummed) - derivatives are"
puts "  NEW files, never edits; develop(develop(x)) == x, proven, so the"
puts "  print can always give you your negative back; the thumbnail is"
puts "  really #{W / 2}x#{H / 2}; and all three baths promoted to the store: #{missing.empty? ? "yes" : "NO"}."
puts
puts "  the shape is every file-attachment pipeline ever shipped: one"
puts "  original, held sacred; one expensive develop step; N cheap"
puts "  derivative baths fanning out from the SAME print in parallel"
puts "  (they share a dependency, not chemistry); and promotion to the"
puts "  store as the atomic finale. the involution check is the one I"
puts "  wish more pipelines had - a transform that can't round-trip is"
puts "  a transform quietly eating data, and in a darkroom you find"
puts "  that out when the wedding photos are already gone."
exit(failures.empty? ? 0 : 1)

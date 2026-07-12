# frozen_string_literal: true

# The Auto-Screencast: a plan that records its own tutorial. Every
# step carries narration and code; as the plan executes, it emits a
# markdown episode - prose, code fence, actual output - and then the
# strange part: the episode is PLAYED BACK. The fences are extracted
# and re-executed in a fresh context, and the replayed outputs must
# match what the recording captured. The tutorial is a doctest of
# itself. Every screencaster knows the shame of the episode that
# doesn't run on the viewer's machine; this one refuses to exist in
# that state. If the episode doesn't run, it doesn't ship.
#
#   bundle exec ruby examples/auto_screencast.rb
#
# Runs offline; exits 1 unless the episode replays faithfully AND
# tampering is detected.

require "bundler/setup"
require "agentic"
require "tmpdir"

Agentic.logger.level = :fatal

EPISODE = [
  {title: "Take the order", narration: "Everything starts with data you can see. No magic yet.",
   code: 'ctx[:order] = {sku: "lamp", qty: 3, unit_cents: 1900}'},
  {title: "Price it", narration: "Multiply, in integer cents. Floats are for lighting, not money.",
   code: "ctx[:subtotal] = ctx[:order][:qty] * ctx[:order][:unit_cents]"},
  {title: "Apply the bulk discount", narration: "Three or more lamps? You're furnishing an office. 10% off.",
   code: "ctx[:total] = (ctx[:order][:qty] >= 3) ? (ctx[:subtotal] * 0.9).round : ctx[:subtotal]"},
  {title: "Print the receipt", narration: "And the payoff - always end an episode with visible output.",
   code: 'ctx[:receipt] = "LAMP x#{ctx[:order][:qty]} - total #{ctx[:total]} cents"'} # rubocop:disable Lint/InterpolationCheck -- the interpolation belongs to the RECORDED code, evaluated at playback
].freeze

# --- the recording session: each step is a task; the camera is a hook ----------------
def record(episode)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 1)
  ctx = {}
  takes = []
  previous = nil
  episode.each do |step|
    task = Agentic::Task.new(description: step[:title], agent_spec: {"name" => step[:title], "instructions" => "w"})
    orchestrator.add_task(task, previous ? [previous] : [], agent: ->(_t) {
      result = eval(step[:code], binding, "episode") # rubocop:disable Security/Eval -- the code IS the content being recorded
      takes << {step: step, output: result.inspect}
      result
    })
    previous = task
  end
  orchestrator.execute_plan
  takes
end

def render_markdown(takes)
  takes.each_with_index.map { |take, i|
    <<~MD
      ## #{i + 1}. #{take[:step][:title]}

      #{take[:step][:narration]}

      ```ruby
      #{take[:step][:code]}
      # => #{take[:output]}
      ```
    MD
  }.join("\n")
end

# --- playback: extract the fences, re-run them fresh, compare ------------------------
def replay(markdown)
  ctx = {}
  markdown.scan(/```ruby\n(.*?)\n# => (.*?)\n```/m).map do |code, recorded|
    {recorded: recorded, replayed: eval(code, binding, "playback").inspect} # rubocop:disable Security/Eval -- replaying the recorded fences is the point
  end
end

puts "THE AUTO-SCREENCAST (if the episode doesn't run, it doesn't ship)"
puts

takes = record(EPISODE)
markdown = render_markdown(takes)
episode_path = File.join(Dir.mktmpdir("screencast"), "episode-042.md")
File.write(episode_path, "# Episode 42: Pricing lamps, honestly\n\n#{markdown}")
puts "  recorded: #{EPISODE.size} scenes -> #{File.basename(episode_path)} (#{File.read(episode_path).lines.size} lines of markdown)"
puts "  final take: #{takes.last[:output]}"
puts

checks = replay(File.read(episode_path))
faithful = checks.all? { |c| c[:recorded] == c[:replayed] }
puts "  playback: #{checks.size}/#{EPISODE.size} fences re-executed in a fresh context"
puts "  every replayed output matches the recording: #{faithful}"
puts

# --- the tamper reel: an editor 'improves' the discount in the markdown --------------
tampered = File.read(episode_path).sub("* 0.9", "* 0.8")
tampered_checks = replay(tampered)
caught = tampered_checks.count { |c| c[:recorded] != c[:replayed] }
puts "  then an editor 'improves' the discount inside the markdown (0.9 -> 0.8):"
puts "  playback catches #{caught} scene(s) where the fence no longer produces"
puts "  its own '# =>' line - the episode convicts its editor."
puts

failures = []
failures << "recording incomplete" unless takes.size == EPISODE.size && takes.last[:output].include?("5130")
failures << "playback unfaithful" unless faithful
failures << "tampering went undetected" unless caught >= 2

puts "  the trick is one rule, applied twice: code you SHOW must be code"
puts "  you RAN. recording enforces it forward (the fence's # => line is"
puts "  the actual output, captured mid-plan by the step that made it),"
puts "  and playback enforces it backward (fences are re-executed and"
puts "  must reproduce their own annotations - so when someone edits the"
puts "  discount in the prose, scene 3 AND the receipt in scene 4 both"
puts "  testify). tutorials rot because they're transcripts of a run"
puts "  nobody can repeat. this one ships with its own repeat button,"
puts "  and refuses to publish a take it can't reproduce."
exit(failures.empty? ? 0 : 1)

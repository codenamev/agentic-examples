# frozen_string_literal: true

# The Wat Museum: seven exhibits of genuine Ruby strangeness, each
# one a task that PROVES its own placard before you're allowed to
# gasp at it. Museums of programming wat usually run on hearsay -
# screenshots of someone else's REPL, half-remembered semantics from
# a conference talk. This museum has a strict acquisitions policy:
# every placard is executed, every claim is checked, and an exhibit
# that cannot demonstrate itself is DEACCESSIONED on the spot. There
# is no magic; there is only semantics you haven't met yet.
#
#   bundle exec ruby examples/wat_museum.rb
#
# Runs offline; exits 1 if the museum contains a single lie.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

EXHIBITS = [
  {name: "The Flip-Flop",
   placard: "(i==3)..(i==5) inside an `if` is a RANGE ACROSS TIME: it turns on at 3, off after 5. Deprecated in 2.6; the community demanded it back.",
   prove: -> {
     picks = (1..10).select { |i| if (i == 3)..(i == 5) then true end } # rubocop:disable Style/IfWithBooleanLiteralBranches, Lint/FlipFlop -- the flip-flop IS the exhibit
     [picks.inspect, picks == [3, 4, 5]]
   }},
  {name: "Some Integers Are More Equal",
   placard: "1.equal?(1) is true (immediates ARE their object), but (2**100).equal?(2**100) is false - bignums are mortal like the rest of us.",
   prove: -> { ["small: #{1.equal?(1)}, big: #{(2**100).equal?(2**100)}", 1.equal?(1) && !(2**100).equal?(2**100)] }},
  {name: "The Sum That Isn't",
   placard: "0.1 + 0.2 != 0.3. The floats did nothing wrong; base 2 simply cannot say 'one tenth' in finitely many words.",
   prove: -> { [(0.1 + 0.2).inspect, 0.1 + 0.2 != 0.3 && (0.1 + 0.2 - 0.3).abs < 1e-15] }}, # rubocop:disable Lint/FloatComparison -- the unreliability IS the exhibit
  {name: "Multiplication Is Join",
   placard: "[1,2,3] * ',' joins. Array#* with an Integer repeats; with a String it becomes #join. One operator, two personalities.",
   # the * IS the exhibit; the linter once rewrote it into join() and nearly deaccessioned the wat
   prove: -> { [([1, 2, 3] * "-").inspect, [1, 2, 3] * "-" == "1-2-3" && [1, 2] * 2 == [1, 2, 1, 2]] }}, # rubocop:disable Style/ArrayJoin
  {name: "defined? Leaves Footprints",
   placard: "defined?(zz = 1) returns 'assignment' WITHOUT assigning - yet zz now exists, as nil. The parser declared the local while merely being asked about it.",
   prove: -> { [eval("[defined?(zz = 1), zz.inspect]").inspect, eval("[defined?(zz = 1), zz.inspect]") == ["assignment", "nil"]] }}, # rubocop:disable Security/Eval, Style/EvalWithLocation -- the exhibit needs a pristine local scope
  {name: "The Banana Constructor",
   placard: "'ba' + 'na' * 2 is 'banana'. Precedence: * binds tighter than +, so 'na' doubles first. Fruit follows.",
   prove: -> { [("ba" + "na" * 2).inspect, "ba" + "na" * 2 == "banana"] }},
  {name: "The Literal That Is Everyone",
   placard: "Under frozen_string_literal, every 'wat' in this file is the SAME OBJECT - the literal was deduplicated at compile time.",
   prove: -> {
     a = "wat"
     b = "wat"
     ["a.equal?(b): #{a.equal?(b)}", a.equal?(b)]
   }}
].freeze

# --- the museum runs its own acquisitions committee, in parallel --------------------
orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 4)
exhibit_tasks = EXHIBITS.to_h do |exhibit|
  task = Agentic::Task.new(description: exhibit[:name], agent_spec: {"name" => exhibit[:name], "instructions" => "prove"})
  orchestrator.add_task(task, agent: ->(_t) {
    observed, verdict = exhibit[:prove].call
    {observed: observed, verdict: verdict}
  })
  [exhibit[:name], task]
end
result = orchestrator.execute_plan

puts "THE WAT MUSEUM (no exhibit without a demonstration)"
puts
lies = []
EXHIBITS.each_with_index do |exhibit, i|
  proof = result.task_result(exhibit_tasks[exhibit[:name]].id).output
  lies << exhibit[:name] unless proof[:verdict]
  puts "  Exhibit #{i + 1}: #{exhibit[:name]} #{proof[:verdict] ? "" : "  ** DEACCESSIONED - PLACARD FALSE **"}"
  exhibit[:placard].scan(/.{1,64}(?:\s|$)/).each { |line| puts "    | #{line.strip}" }
  puts "    demonstrated: #{proof[:observed]}"
  puts
end

puts "  acquisitions report: #{EXHIBITS.size - lies.size}/#{EXHIBITS.size} exhibits verified, #{lies.size} deaccessioned."
puts
puts "  the curatorial position: none of these are bugs, and 'wat' is"
puts "  not an accusation - it's the sound a mental model makes when it"
puts "  updates. the flip-flop is sed's heritage; integer identity is"
puts "  the immediate-value optimization wearing a mask; the float sum"
puts "  is arithmetic being honest about base 2; defined?'s footprint"
puts "  is the parser doing its job earlier than you expected. a museum"
puts "  that executes its placards can afford to exhibit the strange,"
puts "  because it never has to retract - there is no magic, only"
puts "  semantics you haven't met yet, and now you've met seven."
exit(lies.empty? ? 0 : 1)

# frozen_string_literal: true

# Programming with Nothing: FizzBuzz built from lambdas and nothing
# else - no Integer, no Boolean, no if, no % - just Church
# encodings, assembled layer by layer like civilization: numerals
# first, then arithmetic, then predicates and recursion (the Z
# combinator, because Y diverges under strict evaluation), then
# FizzBuzz itself. Each layer is a plan task whose referee converts
# back to native Ruby ONLY at the boundary to check the layer's
# laws, and the final output must equal native FizzBuzz exactly.
# Why do this? Because it's Why Day somewhere, and because nothing
# teaches what a language gives you like building a language out
# of its smallest part. Lambdas all the way down; turtles found
# unnecessary.
#
#   bundle exec ruby examples/programming_with_nothing.rb
#
# Runs offline; exits 1 unless every layer's laws hold and the
# lambda FizzBuzz matches the native one on 1..15.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

# --- layer 0: numbers, from nothing --------------------------------------------------
ZERO = ->(f) { ->(x) { x } }
SUCC = ->(n) { ->(f) { ->(x) { f[n[f][x]] } } }
NUMS = (0..15).reduce([ZERO]) { |acc, _| acc + [SUCC[acc.last]] } # NUMS[i] is Church i

# --- layer 1: arithmetic --------------------------------------------------------------
ADD = ->(m) { ->(n) { ->(f) { ->(x) { m[f][n[f][x]] } } } }
MULT = ->(m) { ->(n) { ->(f) { m[n[f]] } } }
PRED = ->(n) { ->(f) { ->(x) { n[->(g) { ->(h) { h[g[f]] } }][->(_) { x }][->(u) { u }] } } }
SUBTRACT = ->(m) { ->(n) { n[PRED][m] } }

# --- layer 2: truth, comparison, recursion --------------------------------------------
TRUE_ = ->(a) { ->(b) { a } }
FALSE_ = ->(a) { ->(b) { b } }
IF_ = ->(c) { ->(t) { ->(f) { c[t][f] } } }
IS_ZERO = ->(n) { n[->(_) { FALSE_ }][TRUE_] }
LEQ = ->(m) { ->(n) { IS_ZERO[SUBTRACT[m][n]] } }
# The linter flags x[x] as suspicious. It is. Self-application is the
# whole trick of a fixed-point combinator; Russell objected too.
Z = ->(f) { ->(x) { f[->(v) { x[x][v] }] }[->(x) { f[->(v) { x[x][v] }] }] } # rubocop:disable Lint/BinaryOperatorWithIdenticalOperands
MOD = Z[->(f) { ->(m) { ->(n) { IF_[LEQ[n][m]][->(x) { f[SUBTRACT[m][n]][n][x] }][m] } } }]

# --- the boundary: the only place native Ruby is allowed to peek ----------------------
def to_integer(n) = n[->(x) { x + 1 }][0]

def to_boolean(b) = b[true][false]

# --- layer 3: fizzbuzz, with native strings admitted at the very edge -----------------
LAMBDA_FIZZBUZZ = ->(n) {
  IF_[IS_ZERO[MOD[n][NUMS[15]]]]["FizzBuzz"][
    IF_[IS_ZERO[MOD[n][NUMS[3]]]]["Fizz"][
      IF_[IS_ZERO[MOD[n][NUMS[5]]]]["Buzz"][to_integer(n).to_s]]]
}

NATIVE_FIZZBUZZ = ->(i) {
  if i % 15 == 0
    "FizzBuzz"
  else
    (if i % 3 == 0
       "Fizz"
     else
       ((i % 5 == 0) ? "Buzz" : i.to_s)
     end)
  end
}

# --- civilization, assembled as a plan: each layer certifies its laws -----------------
LAYERS = [
  {name: "numerals", laws: -> {
    [to_integer(NUMS[0]) == 0, to_integer(NUMS[7]) == 7, to_integer(SUCC[NUMS[14]]) == 15]
  }},
  {name: "arithmetic", laws: -> {
    [to_integer(ADD[NUMS[3]][NUMS[4]]) == 7, to_integer(MULT[NUMS[3]][NUMS[5]]) == 15,
      to_integer(PRED[NUMS[9]]) == 8, to_integer(SUBTRACT[NUMS[9]][NUMS[4]]) == 5]
  }},
  {name: "predicates + Z", laws: -> {
    [to_boolean(IS_ZERO[ZERO]), !to_boolean(IS_ZERO[NUMS[3]]),
      to_boolean(LEQ[NUMS[3]][NUMS[9]]), !to_boolean(LEQ[NUMS[9]][NUMS[3]]),
      to_integer(MOD[NUMS[14]][NUMS[5]]) == 4, to_integer(MOD[NUMS[15]][NUMS[3]]) == 0]
  }},
  {name: "fizzbuzz", laws: -> {
    (1..15).map { |i| LAMBDA_FIZZBUZZ[NUMS[i]] == NATIVE_FIZZBUZZ[i] }
  }}
].freeze

orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 1) # civilization is sequential
previous = nil
certified = {}
LAYERS.each do |layer|
  task = Agentic::Task.new(description: layer[:name], agent_spec: {"name" => layer[:name], "instructions" => "prove"})
  orchestrator.add_task(task, previous ? [previous] : [], agent: ->(_t) { certified[layer[:name]] = layer[:laws].call })
  previous = task
end
orchestrator.execute_plan

puts "PROGRAMMING WITH NOTHING (lambdas all the way down; turtles found unnecessary)"
puts
certified.each { |name, laws| puts format("  layer %-14s %d/%d laws hold", name, laws.count(&:itself), laws.size) }
puts
puts "  and the payoff, computed without a single Integer in the logic:"
row = (1..15).map { |i| LAMBDA_FIZZBUZZ[NUMS[i]] }
puts "    #{row.join(" ")}"
puts

failures = certified.reject { |_, laws| laws.all? }.keys

puts "  what the stunt is FOR: every layer of convenience your language"
puts "  hands you - numbers, booleans, if, %, recursion - is a library"
puts "  that somebody could have written in the layer below, and here"
puts "  somebody did, in 25 lines. the Z combinator earns special"
puts "  mention: Y diverges under Ruby's strict evaluation, so recursion"
puts "  itself needed an eta-expansion to survive - evaluation ORDER is"
puts "  a real dependency, usually invisible until you build without"
puts "  the safety net. the plan assembled civilization in dependency"
puts "  order with a referee per layer, which is also how you'd want"
puts "  any bootstrap to go: certify arithmetic before you trust the"
puts "  things built on it. happy Why Day; the chunky bacon is implied."
exit(failures.empty? ? 0 : 1)

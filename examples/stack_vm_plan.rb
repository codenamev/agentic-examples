# frozen_string_literal: true

# The Stack VM Plan: I have spent twenty years compiling Ruby onto
# other people's virtual machines, so for the strange round I built
# the inverse: a virtual machine made OUT OF the framework. An
# arithmetic expression compiles to stack bytecode (push/add/sub/
# mul/div - a pocket YARV), and then each INSTRUCTION becomes a
# task: the plan is the instruction stream, the dependency chain is
# the program counter, and the stack threads through previous_output
# as an immutable value. Absurd? Completely. But it decompiles the
# word "executor" back to its roots - and it comes with a peephole
# optimizer, because no instruction stream of mine ships unoptimized.
#
#   bundle exec ruby examples/stack_vm_plan.rb
#
# Runs offline; exits 1 unless the plan-VM agrees with Ruby itself
# on every program, before AND after optimization.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

# --- the compiler: recursive descent, postfix out (a pocket YARV) -------------------
def compile(src)
  tokens = src.scan(%r{\d+|[-+*/()]})
  code = []
  expr = term = factor = nil
  factor = -> {
    if tokens.first == "("
      tokens.shift
      expr.call
      tokens.shift # ")"
    else
      code << [:push, tokens.shift.to_i]
    end
  }
  term = -> {
    factor.call
    while ["*", "/"].include?(tokens.first)
      op = tokens.shift
      factor.call
      code << [(op == "*") ? :mul : :div]
    end
  }
  expr = -> {
    term.call
    while ["+", "-"].include?(tokens.first)
      op = tokens.shift
      term.call
      code << [(op == "+") ? :add : :sub]
    end
  }
  expr.call
  code
end

# --- the peephole optimizer: constant folding until fixpoint ------------------------
def optimize(code)
  folded = code.dup
  loop do
    index = (0..folded.size - 3).find { |i|
      folded[i][0] == :push && folded[i + 1][0] == :push && [:add, :sub, :mul, :div].include?(folded[i + 2][0])
    }
    break unless index
    a, b, op = folded[index][1], folded[index + 1][1], folded[index + 2][0]
    value = {add: a + b, sub: a - b, mul: a * b, div: a / b}.fetch(op)
    folded[index, 3] = [[:push, value]]
  end
  folded
end

# --- the machine: one task per instruction, stack via previous_output ---------------
def run_on_plan_vm(code)
  orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 1) # a program counter, not a pool
  previous = nil
  trace = []
  code.each_with_index do |(op, arg), pc|
    task = Agentic::Task.new(description: "pc=#{pc} #{op} #{arg}".strip, agent_spec: {"name" => op.to_s, "instructions" => "w"})
    orchestrator.add_task(task, previous ? [previous] : [], agent: ->(t) {
      stack = (t.previous_output || []).dup
      case op
      when :push then stack.push(arg)
      when :add then b = stack.pop
                     stack.push(stack.pop + b)
      when :sub then b = stack.pop
                     stack.push(stack.pop - b)
      when :mul then b = stack.pop
                     stack.push(stack.pop * b)
      when :div then b = stack.pop
                     stack.push(stack.pop / b)
      end
      trace << "#{"#{op} #{arg}".strip.ljust(9)} -> [#{stack.join(", ")}]"
      stack.freeze
    })
    previous = task
  end
  result = orchestrator.execute_plan
  [result.task_result(previous.id).output.first, trace]
end

PROGRAMS = ["(2 + 3) * (10 - 4)", "72 / (2 + 6) - 4", "1 + 2 * 3 - 4 / 2"].freeze

puts "THE STACK VM PLAN (a virtual machine whose instructions are jobs)"
puts

failures = []
PROGRAMS.each do |src|
  code = compile(src)
  lean = optimize(code)
  value, trace = run_on_plan_vm(code)
  lean_value, = run_on_plan_vm(lean)
  truth = eval(src) # rubocop:disable Security/Eval -- the reference implementation is Ruby itself, on a literal from this file

  puts "  #{src}  =>  #{value}   (Ruby says #{truth})"
  trace.each { |line| puts "      #{line}" } if src == PROGRAMS.first
  puts "      peephole: #{code.size} instructions -> #{lean.size} (#{lean.map { |op, arg| "#{op} #{arg}".strip }.join("; ")}), same answer: #{lean_value == value}"
  puts
  failures << "#{src}: plan-VM says #{value}, Ruby says #{truth}" unless value == truth
  failures << "#{src}: optimizer changed the answer" unless lean_value == truth
  failures << "#{src}: optimizer didn't optimize" unless lean.size < code.size
end

puts "  what the bit decompiles to: 'the plan is the program' stops"
puts "  being a metaphor when the tasks ARE instructions - the chain is"
puts "  the program counter, previous_output is the operand stack"
puts "  (frozen: this machine has no registers to corrupt), and the"
puts "  whole thing cross-checks against the only reference"
puts "  implementation that matters, Ruby herself. and the peephole"
puts "  pass is the JRuby lesson in one line: the fastest instruction"
puts "  is the one you delete before the executor ever sees it - every"
puts "  program above folded to a SINGLE push, because arithmetic on"
puts "  constants is the compiler's job, not the runtime's. twenty"
puts "  years of VM work, and the moral still fits in a peephole."
exit(failures.empty? ? 0 : 1)

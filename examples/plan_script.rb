# frozen_string_literal: true

# PlanScript: a DSL where BAREWORDS build the graph. Inside the
# block, `fetch` isn't a variable or a method you defined - it's
# method_missing, catching the name and declaring a step; `rank
# after: fetch` catches two. That's the strange half. The principled
# half is that the DSL is a real compiler, and real compilers should
# be BIDIRECTIONAL: the graph decompiles back to canonical
# PlanScript source, the source re-parses to the same graph, and
# emit(parse(emit(g))) == emit(g) - a fixpoint. A config format you
# can regenerate from the live object is documentation that cannot
# lie. One you can't is a one-way door with a nice font.
#
#   bundle exec ruby examples/plan_script.rb
#
# Runs offline; exits 1 unless the round-trip reaches its fixpoint
# and the compiled plan actually executes.

require "bundler/setup"
require "agentic"

Agentic.logger.level = :fatal

class PlanScript
  StepRef = Struct.new(:name)
  attr_reader :steps # {name => [dep names]}

  def initialize
    @steps = {}
  end

  # Barewords arrive here. First sighting declares; `after:` wires.
  def method_missing(name, after: nil)
    @steps[name] ||= []
    @steps[name] |= Array(after).map { |d| d.is_a?(StepRef) ? d.name : d }
    Array(after).each { |d| @steps[d.is_a?(StepRef) ? d.name : d] ||= [] }
    StepRef.new(name)
  end

  def respond_to_missing?(*) = true

  def self.parse(source = nil, &block)
    script = new
    source ? script.instance_eval(source, "plan_script") : script.instance_eval(&block)
    script
  end

  # The decompiler: canonical source from the graph. Sorted deps,
  # declaration order preserved - a NORMAL FORM, so emit is stable.
  def emit
    lines = @steps.map do |name, deps|
      if deps.empty?
        name.to_s
      else
        "#{name} after: #{(deps.size == 1) ? deps.first.inspect : deps.sort.inspect}"
      end
    end
    "plan do\n" + lines.map { |l| "  #{l}" }.join("\n") + "\nend"
  end

  def compile
    orchestrator = Agentic::PlanOrchestrator.new(concurrency_limit: 4)
    tasks = @steps.keys.to_h { |name| [name, Agentic::Task.new(description: name.to_s, agent_spec: {"name" => name.to_s, "instructions" => "w"})] }
    ran = []
    @steps.each do |name, deps|
      orchestrator.add_task(tasks[name], deps.map { |d| tasks[d] }, agent: ->(_t) {
        ran << name
        "#{name}: done"
      })
    end
    [orchestrator, ran]
  end

  # `plan do ... end` inside emitted source
  def plan(&block) = instance_eval(&block)
end

puts "PLANSCRIPT (barewords in, graph out, source back - a compiler that round-trips)"
puts

# --- the script: no symbols, no strings, no defs. just names. -----------------------
original = PlanScript.parse do
  fetch_feed
  dedupe after: fetch_feed
  rank after: dedupe
  summarize after: rank
  render after: [rank, summarize]
end

source = original.emit
puts "  the graph, decompiled to canonical PlanScript:"
source.lines.each { |l| puts "    #{l.rstrip}" }
puts

# --- the fixpoint: parse(emit(g)) == g, and emit stabilizes --------------------------
reparsed = PlanScript.parse(source)
same_graph = reparsed.steps == original.steps
fixpoint = reparsed.emit == source
puts "  parse(emit(graph)) == graph:      #{same_graph}"
puts "  emit(parse(emit(g))) == emit(g):  #{fixpoint} (the decompiler reached its fixpoint)"
puts

# --- and it's not just pretty: the reparsed graph RUNS -------------------------------
orchestrator, ran = reparsed.compile
result = orchestrator.execute_plan
order_ok = ran.index(:fetch_feed) < ran.index(:dedupe) && ran.index(:rank) < ran.index(:render) && ran.index(:summarize) < ran.index(:render)
puts "  compiled and executed the REPARSED graph: #{result.status}, #{ran.size} steps,"
puts "  dependency order respected: #{order_ok}"
puts

failures = []
failures << "round-trip lost the graph" unless same_graph
failures << "emit not a normal form" unless fixpoint
failures << "reparsed plan broken" unless result.status == :completed && order_ok

puts "  two tricks, one principle. the trick you see: method_missing"
puts "  turning barewords into declarations, so the script reads like a"
puts "  napkin sketch (`rank after: dedupe`) with no def, no symbols, no"
puts "  quotes - respond_to_missing? and a Struct, that's the whole"
puts "  parser. the principle underneath: a DSL is a compiler, and"
puts "  compilers you can trust are BIDIRECTIONAL - the live graph"
puts "  decompiles to a canonical source that re-parses to the same"
puts "  graph, byte-stable at one iteration. that's what makes the"
puts "  emitted source safe to commit, diff, and regenerate: it isn't"
puts "  documentation ABOUT the plan, it IS the plan, in its Sunday"
puts "  clothes. one-way DSLs age into folklore; round-trip DSLs age"
puts "  into file formats."
exit(failures.empty? ? 0 : 1)

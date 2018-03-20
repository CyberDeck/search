require 'parslet'    
module Search
  module Dsl
    class Parser < Parslet::Parser
      rule(:text) { match('[^\s"]').repeat(1).as(:text) }
      rule(:number) { (digit >> (dot >> digit).maybe).as(:number) }
      rule(:term) { (number | text).as(:term) }
      rule(:quote) { str('"') }
      rule(:operator) { (str('+') | str('-')).as(:operator) }
      rule(:phrase) do
        (quote >> (term >> space.maybe).repeat >> quote).as(:phrase)
      end
      rule(:clause) { (operator.maybe >> (phrase | term)).as(:clause) }
      rule(:space)  { match('\s').repeat(1) }
      rule(:digit)  { match('[0-9]').repeat(1) }
      rule(:dot)    { match('[,.]').repeat(1,1) }
      rule(:query) { (clause >> space.maybe).repeat.as(:query) }
      root(:query)
    end
  end
end

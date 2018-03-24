require 'parslet'    
module Search

  module Dsl
    class Parser < Parslet::Parser
      rule(:quote) { str('"') }
      rule(:operator) { (str('+') | str('-')).as(:operator) }

      rule(:number_operator) { (str('>') | str('<')).as(:number_operator) }
      rule(:sign) { (str('+') | str('-')) }
      rule(:number) {number_operator.maybe >> space.maybe >> (sign.maybe >> digit >> (dot >> digit).maybe).as(:number) }

      rule(:text) { match('[^\s"]').repeat(1).as(:text) }
      
      rule(:term) { (number | (operator.maybe >> text)).as(:term) }

      rule(:phrase) do
        operator.maybe >> (quote >> (text >> space.maybe).repeat >> quote).as(:phrase)
      end
      rule(:clause) { (phrase | term).as(:clause) }
      rule(:space)  { match('\s').repeat(1) }
      rule(:digit)  { match('[0-9]').repeat(1) }
      rule(:dot)    { match('[,.]').repeat(1,1) }
      rule(:query) { (clause >> space.maybe).repeat.as(:query) }
      root(:query)
    end

    class NumberOperator
      def self.symbol(str)
        case str
        when '>'
          :greater
        when '<'
          :smaller
        when nil
          :equal
        else
          raise "Unknown number operator: #{str}"
        end
      end
    end

    class Operator
      def self.symbol(str)
        case str
        when '+'
          :must
        when '-'
          :must_not
        when nil
          :should
        else
          raise "Unknown operator: #{str}"
        end
      end
    end

    class NumberClause
      attr_accessor :operator, :number

      def initialize(operator, number)
        self.operator = NumberOperator.symbol(operator)
        self.number = Float(number.tr(',', '.'))
      end
    end

    class TextClause
      attr_accessor :operator, :term

      def initialize(operator, term)
        self.operator = Operator.symbol(operator)
        self.term = term
      end
    end

    class PhraseClause
      attr_accessor :operator, :phrase

      def initialize(operator, phrase)
        self.operator = Operator.symbol(operator)
        self.phrase = phrase
      end
    end

    class Query
      attr_accessor :should_clauses, :must_not_clauses, :must_clauses

      def initialize(clauses)
        grouped = clauses.chunk { |c| c.operator }.to_h
        self.should_clauses = grouped.fetch(:should, [])
        self.must_not_clauses = grouped.fetch(:must_not, [])
        self.must_clauses = grouped.fetch(:must, [])
        binding.pry
      end

      #def to_elasticsearch
      #  query = {
      #    :query => {
      #      :bool => {
      #      }
      #    }
      #  }

      #  if should_clauses.any?
      #    query[:query][:bool][:should] = should_clauses.map do |clause|
      #      clause_to_query(clause)
      #    end
      #  end

      #  if must_clauses.any?
      #    query[:query][:bool][:must] = must_clauses.map do |clause|
      #      clause_to_query(clause)
      #    end
      #  end

      #  if must_not_clauses.any?
      #    query[:query][:bool][:must_not] = must_not_clauses.map do |clause|
      #      clause_to_query(clause)
      #    end
      #  end

      #  query
      #end

      #def clause_to_query(clause)
      #  case clause
      #  when TextClause
      #    match(clause.term)
      #  when PhraseClause
      #    match_phrase(clause.phrase)
      #  else
      #    raise "Unknown clause type: #{clause}"
      #  end
      #end

      #def match(term)
      #  {
      #    :match => {
      #      :title => {
      #        :query => term
      #      }
      #    }
      #  }
      #end

      #def match_phrase(phrase)
      #  {
      #    :match_phrase => {
      #      :title => {
      #        :query => phrase
      #      }
      #    }
      #  }
      #end
    end

    class Transformer < Parslet::Transform
      rule(:clause => subtree(:clause)) do
        if clause[:term]
          term = clause[:term]
          if term[:text]
            TextClause.new(term[:operator]&.to_s, term[:text].to_s)
          elsif term[:number]
            NumberClause.new(term[:number_operator]&.to_s, term[:number].to_s)
          else
            raise "Unexpected term type: '#{term}'"
          end
        elsif clause[:phrase]
          phrase = clause[:phrase].map { |p| p[:text].to_s }.join(" ")
          PhraseClause.new(clause[:operator]&.to_s, phrase)
        else
          raise "Unexpected clause type: '#{clause}'"
        end
      end

      rule(:query => sequence(:clauses)) { Query.new(clauses) }
    end
  end
end

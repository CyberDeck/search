require 'parslet'    
module Search
  extend ActiveSupport::Concern

  class_methods do
    module Searchable
      def self.parse(fields_text, fields_number, what)
        fields_text = [fields_text] unless fields_text.is_a?(Array)
        fields_number = [fields_number] unless fields_number.is_a?(Array)
        query = Search::Dsl::Transformer.new.apply(Search::Dsl::Parser.new.parse(what))
        ret = query.where(fields_text, fields_number)
        ret
      end
      
      def self.text(fields, keywords)
        tokens = keywords.tokenize_search_text.first(10)
        if fields.is_a? Array
          fields.map{|f| f.matches_any(tokens)}.reduce(:or)
        else
          fields.matches_any(tokens)
        end
      end

      def self.number(fields, keywords)
        tokens = keywords.tokenize_search_number.first(10)
        if fields.is_a? Array
          fields.map{|f| f.in(tokens)}.reduce(:or)
        else
          fields.in(tokens)
        end
      end
    end
  end

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

      def to_s
        self.term
      end
    end

    class PhraseClause
      attr_accessor :operator, :phrase

      def initialize(operator, phrase)
        self.operator = Operator.symbol(operator)
        self.phrase = phrase
      end

      def to_s
        self.phrase
      end
    end

    class Query
      attr_accessor :should_clauses, :must_not_clauses, :must_clauses
      attr_accessor :equal_clauses, :greater_clauses, :smaller_clauses

      def initialize(clauses)
        grouped = clauses.chunk { |c| c.operator }.to_h
        self.should_clauses = grouped.fetch(:should, []).map{|f| "%#{f.to_s}%"}
        self.must_not_clauses = grouped.fetch(:must_not, []).map{|f| "%#{f.to_s}%"}
        self.must_clauses = grouped.fetch(:must, []).map{|f| "%#{f.to_s}%"}
        self.equal_clauses = grouped.fetch(:equal, []).map{|f| f.number}
        self.smaller_clauses = grouped.fetch(:smaller, []).map{|f| f.number}
        self.greater_clauses = grouped.fetch(:greater, []).map{|f| f.number}
      end

      def where(fields_text, fields_number)
        [where_text(fields_text), where_number(fields_number)].reduce(:and)
      end

      def where_text(fields)
        query = Arel::Nodes::True.new
        query = query.and(fields.map{|f| f.matches_any(self.should_clauses)}.reduce(:or)) unless self.should_clauses.length.zero?
        query = query.and(self.must_clauses.map{|t| fields.map{|f| f.matches(t)}.reduce(:or)}.reduce(:and)) unless self.must_clauses.length.zero?
        query = query.and(self.must_not_clauses.map{|t| fields.map{|f| f.does_not_match(t)}.reduce(:and)}.reduce(:and)) unless self.must_not_clauses.length.zero?
        query
      end

      def where_number(fields)
        query = Arel::Nodes::True.new
        query = query.and(fields.map{|f| f.eq_any(self.equal_clauses)}.reduce(:or)) unless self.equal_clauses.length.zero?
        query = query.and(fields.map{|f| f.lt_any(self.smaller_clauses)}.reduce(:or)) unless self.smaller_clauses.length.zero?
        query = query.and(fields.map{|f| f.gt_any(self.greater_clauses)}.reduce(:or)) unless self.greater_clauses.length.zero?
        query
      end
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

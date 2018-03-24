require 'search/dsl'

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
end

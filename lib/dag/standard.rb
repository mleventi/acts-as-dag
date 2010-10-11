module Dag
  module Standard

    def self.included(base)
      base.send :include, NonPolyEdgeInstanceMethods
    end

    #Encapsulates the necessary information about a graph node
    class EndPoint
      #Does an endpoint match another endpoint or model instance
      def matches?(other)
        self.id == other.id
      end

      #Factory Construction method that creates an endpoint from a model
      def self.from_resource(resource)
        self.new(resource.id)
      end

      #Factory Construction method that creates an endpoint from a model if necessary
      def self.from(obj)
        return obj if obj.kind_of?(EndPoint)
        self.from_resource(obj)
      end

      #Initializes an endpoint based on an Id
      def initialize(id)
        @id = id
      end

      attr_reader :id
    end

    #Encapsulates information about the source of a link
    class Source < EndPoint
      #Factory Construction method creates a source instance from a link
      def self.from_edge(edge)
        self.new(edge.ancestor_id)
      end
    end
    #Encapsulates information about the sink of a link
    class Sink < EndPoint
      #Factory Construction method creates a sink instance from a link
      def self.from_edge(edge)
        self.new(edge.descendant_id)
      end
    end

    #Builds a hash that describes a link from a source and a sink
    def conditions_for(source, sink)
      {
              ancestor_id_column_name => source.id,
              descendant_id_column_name => sink.id
      }
    end

    #Instance methods included into the link model for a non-polymorphic DAG
    module NonPolyEdgeInstanceMethods
    end

  end
end
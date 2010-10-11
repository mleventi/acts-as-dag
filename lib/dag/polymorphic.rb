module Dag
  module Polymorphic

    def self.included(base)
      base.send :include, PolyEdgeInstanceMethods
    end

    #Contains nested classes in the link model for polymorphic DAGs
    #Encapsulates the necessary information about a graph node
    class EndPoint
      #Does the endpoint match a model or another endpoint
      def matches?(other)
        return (self.id == other.id) && (self.type == other.type) if other.is_a?(EndPoint)
        (self.id == other.id) && (self.type == other.class.to_s)
      end

      #Factory Construction method that creates an EndPoint instance from a model
      def self.from_resource(resource)
        self.new(resource.id, resource.class.to_s)
      end

      #Factory Construction method that creates an EndPoint instance from a model if necessary
      def self.from(obj)
        return obj if obj.kind_of?(EndPoint)
        self.from_resource(obj)
      end

      #Initializes the EndPoint instance with an id and type
      def initialize(id, type)
        @id = id
        @type = type
      end

      attr_reader :id, :type
    end

    #Encapsulates information about the source of a link
    class Source < EndPoint
      #Factory Construction method that generates a source from a link
      def self.from_edge(edge)
        self.new(edge.ancestor_id, edge.ancestor_type)
      end
    end

    #Encapsulates information about the sink (destination) of a link
    class Sink < EndPoint
      #Factory Construction method that generates a sink from a link
      def self.from_edge(edge)
        self.new(edge.descendant_id, edge.descendant_type)
      end
    end

    #Contains class methods that extend the link model for polymorphic DAGs
    #Builds a hash that describes a link from a source and a sink
    def conditions_for(source, sink)
      {
              ancestor_id_column_name => source.id,
              ancestor_type_column_name => source.type,
              descendant_id_column_name => sink.id,
              descendant_type_column_name => sink.type
      }
    end

    #Instance methods included into link model for a polymorphic DAG
    module PolyEdgeInstanceMethods
      def ancestor_type
        self[ancestor_type_column_name]
      end

      def descendant_type
        self[descendant_type_column_name]
      end
    end

  end
end

module Dag
  module Edges

    def self.included(base)
      base.send :include, EdgeInstanceMethods
    end

    #Class methods that extend the link model for both polymorphic and non-polymorphic graphs
    #Returns a new edge between two points
    def build_edge(ancestor, descendant)
      source = self::EndPoint.from(ancestor)
      sink = self::EndPoint.from(descendant)
      conditions = self.conditions_for(source, sink)
      path = self.new(conditions)
      path.make_direct
      path
    end

    #Finds an edge between two points, Must be direct
    def find_edge(ancestor, descendant)
      source = self::EndPoint.from(ancestor)
      sink = self::EndPoint.from(descendant)
      self.first :conditions => self.conditions_for(source, sink).merge!({direct_column_name => true})
    end

    #Finds a link between two points
    def find_link(ancestor, descendant)
      source = self::EndPoint.from(ancestor)
      sink = self::EndPoint.from(descendant)
      self.first :conditions => self.conditions_for(source, sink)
    end

    #Finds or builds an edge between two points
    def find_or_build_edge(ancestor, descendant)
      edge = self.find_edge(ancestor, descendant)
      return edge unless edge.nil?
      return build_edge(ancestor, descendant)
    end

    #Creates an edge between two points using save
    def create_edge(ancestor, descendant)
      link = self.find_link(ancestor, descendant)
      if link.nil?
        edge = self.build_edge(ancestor, descendant)
        return edge.save
      else
        link.make_direct
        return link.save
      end
    end

    #Creates an edge between two points using save! Returns created edge
    def create_edge!(ancestor, descendant)
      link = self.find_link(ancestor, descendant)
      if link.nil?
        edge = self.build_edge(ancestor, descendant)
        edge.save!
        edge
      else
        link.make_direct
        link.save!
        link
      end
    end

    #Alias for create_edge
    def connect(ancestor, descendant)
      self.create_edge(ancestor, descendant)
    end

    #Alias for create_edge!
    def connect!(ancestor, descendant)
      self.create_edge!(ancestor, descendant)
    end

    #Determines if a link exists between two points
    def connected?(ancestor, descendant)
      !self.find_link(ancestor, descendant).nil?
    end

    #Finds the longest path between ancestor and descendant returning as an array
    def longest_path_between(ancestor, descendant, path=[])
      longest = []
      ancestor.children.each do |child|
        if child == descendant
          temp = path.clone
          temp << child
          if temp.length > longest.length
            longest = temp
          end
        elsif self.connected?(child, descendant)
          temp = path.clone
          temp << child
          temp = self.longest_path_between(child, descendant, temp)
          if temp.length > longest.length
            longest = temp
          end
        end
      end
      longest
    end

    #Finds the shortest path between ancestor and descendant returning as an array
    def shortest_path_between(ancestor, descendant, path=[])
      shortest = []
      ancestor.children.each do |child|
        if child == descendant
          temp = path.clone
          temp << child
          if shortest.blank? || temp.length < shortest.length
            shortest = temp
          end
        elsif self.connected?(child, descendant)
          temp = path.clone
          temp << child
          temp = self.shortest_path_between(child, descendant, temp)
          if shortest.blank? || temp.length < shortest.length
            shortest = temp
          end
        end
      end
      return shortest
    end

    #Determines if an edge exists between two points
    def edge?(ancestor, descendant)
      !self.find_edge(ancestor, descendant).nil?
    end

    #Alias for edge
    def direct?(ancestor, descendant)
      self.edge?(ancestor, descendant)
    end

    #Instance methods included into the link model for polymorphic and non-polymorphic DAGs
    module EdgeInstanceMethods

      attr_accessor :do_not_perpetuate

      #Fill default direct and count values if necessary. In place of after_initialize method
      def fill_defaults
        self[direct_column_name] = true if self[direct_column_name].nil?
        self[count_column_name] = 0 if self[count_column_name].nil?
      end

      #Whether the edge can be destroyed
      def destroyable?
        (self.count == 0) || (self.direct? && self.count == 1)
      end

      #Raises an exception if the edge is not destroyable. Otherwise makes the edge indirect before destruction to cleanup graph.
      def destroyable!
        raise ActiveRecord::ActiveRecordError, 'ERROR: cannot destroy this edge' unless destroyable?
        #this triggers rewiring on destruction via perpetuate
        if self.direct?
          self[direct_column_name] = false
        end
        true
      end

      #Analyzes the changes in a model instance and rewires as necessary.
      def perpetuate
        #flag set by links that were modified in association
        return true if self.do_not_perpetuate

        #if edge changed this was manually altered
        if direct_changed?
          if self.direct?
            self[count_column_name] += 1
          else
            self[count_column_name] -= 1
          end
          self.wiring
        end
      end

      #Id of the ancestor
      def ancestor_id
        self[ancestor_id_column_name]
      end

      #Id of the descendant
      def descendant_id
        self[descendant_id_column_name]
      end

      #Count of the edge, ie the edge exists in X ways
      def count
        self[count_column_name]
      end

      #Changes the count of the edge. DO NOT CALL THIS OUTSIDE THE PLUGIN
      def internal_count=(val)
        self[count_column_name] = val
      end

      #Whether the link is direct, ie manually created
      def direct?
        self[direct_column_name]
      end

      #Whether the link is an edge?
      def edge?
        self[direct_column_name]
      end

      #Makes the link direct, ie an edge
      def make_direct
        self[direct_column_name] = true
      end

      #Makes an edge indirect, ie a link.
      def make_indirect
        self[direct_column_name] = false
      end

      #Source of the edge, creates if necessary
      def source
        @source = self.class::Source.from_edge(self) if @source.nil?
        @source
      end

      #Sink (destination) of the edge, creates if necessary
      def sink
        @sink = self.class::Sink.from_edge(self) if @sink.nil?
        @sink
      end

      #All links that end at the source
      def links_to_source
        self.class.with_descendant_point(self.source)
      end

      #all links that start from the sink
      def links_from_sink
        self.class.with_ancestor_point(self.sink)
      end

      protected

      # Changes on a wire based on the count (destroy or save!) (should not be called outside this plugin)
      def push_associated_modification!(edge)
        raise ActiveRecord::ActiveRecordError, 'ERROR: cannot modify our self in this way' if edge == self
        edge.do_not_perpetuate = true
        if edge.count == 0
          edge.destroy
        else
          edge.save!
        end
      end

      #Updates the wiring of edges that dependent on the current one
      def rewire_crossing(above_leg, below_leg)
        if above_leg.count_changed?
          was = above_leg.count_was
          was = 0 if was.nil?
          above_leg_count = above_leg.count - was
          if below_leg.count_changed?
            raise ActiveRecord::ActiveRecordError, 'ERROR: both legs cannot 0 normal count change'
          else
            below_leg_count = below_leg.count
          end
        else
          above_leg_count = above_leg.count
          if below_leg.count_changed?
            was = below_leg.count_was
            was = 0 if was.nil?
            below_leg_count = below_leg.count - was
          else
            raise ActiveRecord::ActiveRecordError, 'ERROR: both legs cannot have count changes'
          end
        end
        count = above_leg_count * below_leg_count
        source = above_leg.source
        sink = below_leg.sink
        bridging_leg = self.class.find_link(source, sink)
        if bridging_leg.nil?
          bridging_leg = self.class.new(self.class.conditions_for(source, sink))
          bridging_leg.make_indirect
          bridging_leg.internal_count = 0
        end
        bridging_leg.internal_count = bridging_leg.count + count
        bridging_leg
      end

      #Find the edges that need to be updated
      def wiring
        source = self.source
        sink = self.sink
        above_sources = []
        self.links_to_source.each do |edge|
          above_sources << edge.source
        end
        below_sinks = []
        self.links_from_sink.each do |edge|
          below_sinks << edge.sink
        end
        above_bridging_legs = []
        #everything above me tied to my sink
        above_sources.each do |above_source|
          above_leg = self.class.find_link(above_source, source)
          above_bridging_leg = self.rewire_crossing(above_leg, self)
          above_bridging_legs << above_bridging_leg unless above_bridging_leg.nil?
        end

        #everything beneath me tied to my source
        below_sinks.each do |below_sink|
          below_leg = self.class.find_link(sink, below_sink)
          below_bridging_leg = self.rewire_crossing(self, below_leg)
          self.push_associated_modification!(below_bridging_leg)
          above_bridging_legs.each do |above_bridging_leg|
            long_leg = self.rewire_crossing(above_bridging_leg, below_leg)
            self.push_associated_modification!(long_leg)
          end
        end
        above_bridging_legs.each do |above_bridging_leg|
          self.push_associated_modification!(above_bridging_leg)
        end
      end
    end

  end
end
module ActiveRecord
	module Acts
		module Dag
			def self.included(base)
				base.extend(SingletonMethods)
			end
			module SingletonMethods
				#Sets up a model to act as dag links for models specified under the :for option
				def acts_as_dag_links(options = {})
					conf = {
						:ancestor_id_column => 'ancestor_id',
						:ancestor_type_column => 'ancestor_type', 
						:descendant_id_column => 'descendant_id',
						:descendant_type_column => 'descendant_type', 
						:direct_column => 'direct', 
						:count_column => 'count',
						:polymorphic => false,
						:node_class_name => nil}
					conf.update(options)
					
					unless conf[:polymorphic]
						if conf[:node_class_name].nil?
							raise ActiveRecord::ActiveRecordError, 'Nonpolymorphic graphs need to specify :node_class_name with the recieving class like belong_to'
						end 
					end
					
					write_inheritable_attribute :acts_as_dag_options, conf
					class_inheritable_reader :acts_as_dag_options
					
					extend Columns
					include Columns
					
					#access to _changed? and _was for (edge,count) if not default
					unless direct_column_name == 'direct'
						module_eval <<-"end_eval",__FILE__, __LINE__
						def direct_changed?
							self.#{direct_column_name}_changed?
						end
						def direct_was
							self.#{direct_column_name}_was
						end
						end_eval
					end
					
					unless count_column_name == 'count'
						module_eval <<-"end_eval",__FILE__, __LINE__
						def count_changed?
							self.#{count_column_name}_changed?
						end
						def count_was
							self.#{count_column_name}_was
						end
						end_eval
					end
					
					internal_columns = [ancestor_id_column_name,descendant_id_column_name]
					edge_class_name = self.to_s
					
					direct_column_name.intern
					count_column_name.intern
					
					#links to ancestor and descendant
					if acts_as_dag_polymorphic?
						extend PolyColumns
						include PolyColumns
						
						internal_columns << ancestor_type_column_name
						internal_columns << descendant_type_column_name
						
						belongs_to :ancestor, :polymorphic => true
						belongs_to :descendant, :polymorphic => true
						
						validates_presence_of ancestor_type_column_name, descendant_type_column_name
						validates_uniqueness_of ancestor_id_column_name, :scope => [ancestor_type_column_name,descendant_type_column_name,descendant_id_column_name]
						
						named_scope :with_ancestor, lambda {|ancestor| {:conditions => {ancestor_id_column_name => ancestor.id, ancestor_type_column_name => ancestor.class.to_s}}}
						named_scope :with_descendant, lambda {|descendant| {:conditions => {descendant_id_column_name => descendant.id, descendant_type_column_name => descendant.class.to_s}}}
						
						named_scope :with_ancestor_point, lambda {|point| {:conditions => {ancestor_id_column_name => point.id, ancestor_type_column_name => point.type}}}
						named_scope :with_descendant_point, lambda {|point| {:conditions => {descendant_id_column_name => point.id, descendant_type_column_name => point.type}}}
						
						extend PolyEdgeClassMethods
						include PolyEdgeClasses
						include PolyEdgeInstanceMethods  
					else
						belongs_to :ancestor, :foreign_key => ancestor_id_column_name, :class_name => acts_as_dag_options[:node_class_name]
						belongs_to :descendant, :foreign_key => descendant_id_column_name, :class_name => acts_as_dag_options[:node_class_name]
						
						validates_uniqueness_of ancestor_id_column_name, :scope => [descendant_id_column_name]
						
						named_scope :with_ancestor, lambda {|ancestor| {:conditions => {ancestor_id_column_name => ancestor.id}}}
						named_scope :with_descendant, lambda {|descendant| {:conditions => {descendant_id_column_name => descendant.id}}}
						
						named_scope :with_ancestor_point, lambda {|point| {:conditions => {ancestor_id_column_name => point.id}}}
						named_scope :with_descendant_point, lambda {|point| {:conditions => {descendant_id_column_name => point.id}}}
						
						extend NonPolyEdgeClassMethods
						include NonPolyEdgeClasses
						include NonPolyEdgeInstanceMethods
					end
					
					named_scope :direct, :conditions => {:direct => true}
					named_scope :indirect, :conditions => {:direct => false}
					
					named_scope :ancestor_nodes, :joins => :ancestor
					named_scope :descendant_nodes, :joins => :descendant
					
					validates_presence_of ancestor_id_column_name, descendant_id_column_name
					validates_numericality_of ancestor_id_column_name, descendant_id_column_name
					
					extend EdgeClassMethods
					include EdgeInstanceMethods
					
					before_destroy :destroyable!, :perpetuate
					before_save :perpetuate
					before_validation_on_update :field_check, :fill_defaults
					before_validation_on_create :fill_defaults
					
					#internal fields
					code = 'def field_check ' + "\n"
					internal_columns.each do |column|
						code +=  "if " + column + "_changed? \n" + ' raise ActiveRecord::ActiveRecordError, "Column: '+column+' cannot be changed for an existing record it is immutable"' + "\n end \n"
					end
					code += 'end'
					module_eval code
					
					[count_column_name].each do |column|
						module_eval <<-"end_eval", __FILE__, __LINE__
						def #{column}=(x)
							raise ActiveRecord::ActiveRecordError, "Unauthorized assignment to #{column}: it's an internal field handled by acts_as_dag code."
						end
						end_eval
					end       
				end      
				def has_dag_links(options = {})
					conf = {
						:class_name => nil,
						:prefix => '',
						:ancestor_class_names => [],
						:descendant_class_names => []
					}
					conf.update(options)
					
					#check that class_name is filled
					if conf[:link_class_name].nil?
						raise ActiveRecord::ActiveRecordError, "has_dag must be provided with :link_class_name option"
					end
					
					#add trailing '_' to prefix
					unless conf[:prefix] == ''
						conf[:prefix] += '_'
					end
					
					prefix = conf[:prefix]
					dag_link_class_name = conf[:link_class_name]
					dag_link_class = conf[:link_class_name].constantize        
					
					if dag_link_class.acts_as_dag_polymorphic?
						self.class_eval <<-EOL
              has_many :#{prefix}links_as_ancestor, :as => :ancestor, :class_name => '#{dag_link_class_name}'
              has_many :#{prefix}links_as_descendant, :as => :descendant, :class_name => '#{dag_link_class_name}'
            
              has_many :#{prefix}links_as_parent, :as => :ancestor, :class_name => '#{dag_link_class_name}', :conditions => {'#{dag_link_class.direct_column_name}' => true}
              has_many :#{prefix}links_as_child, :as => :descendant, :class_name => '#{dag_link_class_name}', :conditions => {'#{dag_link_class.direct_column_name}' => true}
              
            EOL
						
						ancestor_table_names = []
						parent_table_names = []
						conf[:ancestor_class_names].each do |class_name|
							table_name = class_name.tableize
							self.class_eval <<-EOL2
                has_many :#{prefix}links_as_descendant_for_#{table_name}, :as => :descendant, :class_name => '#{dag_link_class_name}', :conditions => {'#{dag_link_class.ancestor_type_column_name}' => '#{class_name}'}
                has_many :#{prefix}ancestor_#{table_name}, :through => :#{prefix}links_as_descendant_for_#{table_name}, :source => :ancestor, :source_type => '#{class_name}'
                has_many :#{prefix}links_as_child_for_#{table_name}, :as => :descendant, :class_name => '#{dag_link_class_name}', :conditions => {'#{dag_link_class.ancestor_type_column_name}' => '#{class_name}','#{dag_link_class.direct_column_name}' => true}
                has_many :#{prefix}parent_#{table_name}, :through => :#{prefix}links_as_child_for_#{table_name}, :source => :ancestor, :source_type => '#{class_name}'
              
              	def #{prefix}root_for_#{table_name}?
									return self.links_as_descendant_for_#{table_name}.empty?
            		end
              EOL2
							ancestor_table_names << (prefix+'ancestor_'+table_name)
							parent_table_names << (prefix+'parent_'+table_name)
							unless conf[:descendant_class_names].include?(class_name)
								#this apparently is only one way is we can create some aliases making things easier
								self.class_eval "has_many :#{prefix}#{table_name}, :through => :#{prefix}links_as_descendant_for_#{table_name}, :source => :ancestor, :source_type => '#{class_name}'"   
							end
						end
						
						unless conf[:ancestor_class_names].empty?
							self.class_eval <<-EOL25
								def #{prefix}ancestors
									return #{ancestor_table_names.join(' + ')}
								end
								def #{prefix}parents
									return #{parent_table_names.join(' + ')}
								end
							EOL25
						else
							self.class_eval <<-EOL26
								def #{prefix}ancestors
									a = []
									#{prefix}links_as_descendant.each do |link|
										a << link.ancestor
									end
									return a
								end
								def #{prefix}parents
									a = []
									#{prefix}links_as_child.each do |link|
										a << link.ancestor
									end
									return a
								end
							EOL26
						end
						
						descendant_table_names = []
						child_table_names = []
						conf[:descendant_class_names].each do |class_name|
							table_name = class_name.tableize
							self.class_eval <<-EOL3
                has_many :#{prefix}links_as_ancestor_for_#{table_name}, :as => :ancestor, :class_name => '#{dag_link_class_name}', :conditions => {'#{dag_link_class.descendant_type_column_name}' => '#{class_name}'}
                has_many :#{prefix}descendant_#{table_name}, :through => :#{prefix}links_as_ancestor_for_#{table_name}, :source => :descendant, :source_type => '#{class_name}'
            
                has_many :#{prefix}links_as_parent_for_#{table_name}, :as => :ancestor, :class_name => '#{dag_link_class_name}', :conditions => {'#{dag_link_class.descendant_type_column_name}' => '#{class_name}','#{dag_link_class.direct_column_name}' => true}
                has_many :#{prefix}child_#{table_name}, :through => :#{prefix}links_as_parent_for_#{table_name}, :source => :descendant, :source_type => '#{class_name}'
								
								def #{prefix}leaf_for_#{table_name}?
                	return self.links_as_ancestor_for_#{table_name}.empty?
              	end
              EOL3
							descendant_table_names << (prefix+'descendant_'+table_name)
							child_table_names << (prefix+'child_'+table_name)
							unless conf[:ancestor_class_names].include?(class_name)
								self.class_eval "has_many :#{prefix}#{table_name}, :through => :#{prefix}links_as_ancestor_for_#{table_name}, :source => :descendant, :source_type => '#{class_name}'"
							end
						end
						
						unless conf[:descendant_class_names].empty?
							self.class_eval <<-EOL35
								def #{prefix}descendants
									return #{descendant_table_names.join(' + ')}
								end
								def #{prefix}children
									return #{child_table_names.join(' + ')}
								end
							EOL35
						else
							self.class_eval <<-EOL36
								def #{prefix}descendants
									d = []
									#{prefix}links_as_ancestor.each do |link|
										d << link.descendant
									end
									return d
								end
								def #{prefix}children
									d = []
									#{prefix}links_as_parent.each do |link|
										d << link.descendant
									end
									return d
								end
							EOL36
						end
					else
						self.class_eval <<-EOL4
              has_many :#{prefix}links_as_ancestor, :foreign_key => '#{dag_link_class.ancestor_id_column_name}', :class_name => '#{dag_link_class_name}'
              has_many :#{prefix}links_as_descendant, :foreign_key => '#{dag_link_class.descendant_id_column_name}', :class_name => '#{dag_link_class_name}'
            
              has_many :#{prefix}ancestors, :through => :#{prefix}links_as_descendant, :source => :ancestor
              has_many :#{prefix}descendants, :through => :#{prefix}links_as_ancestor, :source => :descendant
            
              has_many :#{prefix}links_as_parent, :foreign_key => '#{dag_link_class.ancestor_id_column_name}', :class_name => '#{dag_link_class_name}', :conditions => {'#{dag_link_class.direct_column_name}' => true}
              has_many :#{prefix}links_as_child, :foreign_key => '#{dag_link_class.descendant_id_column_name}', :class_name => '#{dag_link_class_name}', :conditions => {'#{dag_link_class.direct_column_name}' => true}
                        
              has_many :#{prefix}parents, :through => :#{prefix}links_as_child, :source => :ancestor
              has_many :#{prefix}children, :through => :#{prefix}links_as_parent, :source => :descendant
              
            EOL4
					end
					self.class_eval <<-EOL5
            def #{prefix}leaf?
              return self.#{prefix}links_as_ancestor.empty?
						end
						def #{prefix}root?
							return self.#{prefix}links_as_descendant.empty?
						end
					EOL5
				end
			end
			
			
			
			
			#Methods that show the columns for polymorphic DAGs
			module PolyColumns
				def ancestor_type_column_name
					acts_as_dag_options[:ancestor_type_column]
				end
				
				def descendant_type_column_name
					acts_as_dag_options[:descendant_type_column]
				end
			end
			
			#Methods that show columns
			module Columns
				def ancestor_id_column_name
					acts_as_dag_options[:ancestor_id_column]
				end
				
				def descendant_id_column_name
					acts_as_dag_options[:descendant_id_column]
				end
				
				def direct_column_name
					acts_as_dag_options[:direct_column]
				end
				
				def count_column_name
					acts_as_dag_options[:count_column]
				end
				
				def acts_as_dag_polymorphic?
					acts_as_dag_options[:polymorphic]
				end
			end
			
			#Contains class methods that extend the link model for polymorphic DAGs
			module PolyEdgeClassMethods
				#Builds a hash that describes a link from a source and a sink
				def conditions_for(source,sink)
					{
						ancestor_id_column_name => source.id,
						ancestor_type_column_name => source.type,
						descendant_id_column_name => sink.id,
						descendant_type_column_name => sink.type
					}
				end
			end
			#Contains nested classes in the link model for polymorphic DAGs 
			module PolyEdgeClasses
				#Encapsulates the necessary information about a graph node
				class EndPoint
					#Does the endpoint match a model or another endpoint   
					def matches?(other)
						return (self.id == other.id) && (self.type == other.type) if other.is_a?(EndPoint)
						return (self.id == other.id) && (self.type == other.class.to_s)
					end
					
					#Factory Construction method that creates an EndPoint instance from a model
					def self.from_resource(resource)
						self.new(resource.id,resource.class.to_s)
					end
					
					#Factory Construction method that creates an EndPoint instance from a model if necessary
					def self.from(obj)
						return obj if obj.kind_of?(EndPoint)
						return self.from_resource(obj)
					end
					
					#Initializes the EndPoint instance with an id and type
					def initialize(id,type)
						@id = id
						@type = type
					end
					
					attr_reader :id, :type
				end
				
				#Encapsulates information about the source of a link
				class Source < EndPoint
					#Factory Construction method that generates a source from a link
					def self.from_edge(edge)
						self.new(edge.ancestor_id,edge.ancestor_type)
					end
				end
				
				#Encapsulates information about the sink (destination) of a link
				class Sink < EndPoint
					#Factory Construction method that generates a sink from a link
					def self.from_edge(edge)
						self.new(edge.descendant_id,edge.descendant_type)
					end
				end
			end
			
			#Contains class methods that extend the link model for a nonpolymorphic DAG
			module NonPolyEdgeClassMethods
				#Builds a hash that describes a link from a source and a sink
				def conditions_for(source,sink)
					{
						ancestor_id_column_name => source.id,
						descendant_id_column_name => sink.id
					}
				end
			end
			#Contains nested classes in the link model for a nonpolymorphic DAG
			module NonPolyEdgeClasses 
				#Encapsulates the necessary information about a graph node    
				class EndPoint
					#Does an endpoint match another endpoint or model instance
					def matches?(other)
						return (self.id == other.id)
					end
					
					#Factory Construction method that creates an endpoint from a model
					def self.from_resource(resource)
						self.new(resource.id)
					end
					
					#Factory Construction method that creates an endpoint from a model if necessary
					def self.from(obj)
						return obj if obj.kind_of?(EndPoint)
						return self.from_resource(obj)
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
						return self.new(edge.ancestor_id)
					end
				end
				#Encapsulates information about the sink of a link
				class Sink < EndPoint
					#Factory Construction method creates a sink instance from a link
					def self.from_edge(edge)
						return self.new(edge.descendant_id)
					end
				end
			end
			
			#Class methods that extend the link model for both polymorphic and nonpolymorphic graphs
			module EdgeClassMethods
				
				#Returns a new edge between two points
				def build_edge(ancestor,descendant)
					source = self::EndPoint.from(ancestor)
					sink = self::EndPoint.from(descendant)
					conditions = self.conditions_for(source,sink)
					path = self.new(conditions)
					path.make_direct
					return path
				end
				
				#Finds an edge between two points, Must be direct
				def find_edge(ancestor,descendant)
					source = self::EndPoint.from(ancestor)
					sink = self::EndPoint.from(descendant)
					edge = self.find(:first,:conditions => self.conditions_for(source,sink).merge!({direct_column_name => true}))
					return edge
				end
				
				#Finds a link between two points
				def find_link(ancestor,descendant)
					source = self::EndPoint.from(ancestor)
					sink = self::EndPoint.from(descendant)
					link = self.find(:first,:conditions => self.conditions_for(source,sink))
					return link
				end 
				
				#Finds or builds an edge between two points
				def find_or_build_edge(ancestor,descendant)
					edge = self.find_edge(ancestor,descendant)
					return edge unless edge.nil?
					return build_edge(ancestor,descendant)
				end
				
				#Creates an edge between two points using save
				def create_edge(ancestor,descendant)
					link = self.find_link(ancestor,descendant)
					if link.nil?
						edge = self.build_edge(ancestor,descendant)
						return edge.save
					else
						link.make_direct
						return link.save
					end
				end
				
				#Creates an edge between two points using save! Returns created edge
				def create_edge!(ancestor,descendant)
					link = self.find_link(ancestor,descendant)
					if link.nil?
						edge = self.build_edge(ancestor,descendant)
						edge.save!
						return edge
					else
						link.make_direct
						link.save!
						return link
					end
				end
				
				#Alias for create_edge
				def connect(ancestor,descendant)
					return self.create_edge(ancestor,descendant)
				end
				
				#Alias for create_edge!
				def connect!(ancestor,descendant)
					return self.create_edge!(ancestor,descendant)
				end
				
				#Determines if a link exists between two points
				def connected?(ancestor,descendant)
					return !self.find_link(ancestor,descendant).nil?
				end
				
				#Finds the longest path between ancestor and descendant returning as an array
				def longest_path_between(ancestor,descendant,path=[])
					longest = []
					ancestor.children.each do |child|
						if child == descendent
							temp = path.clone
							temp << child
							if temp.length > longest.length
								longest = temp
							end
						elsif self.connected?(child,descendant)
							temp = path.clone
							temp << child
							temp = self.longest_path_between(child,descendant,temp)
							if temp.length > longest.length
								longest = temp
							end
						end
					end
					return longest
				end
				
				#Determines if an edge exists between two points
				def edge?(ancestor,descendant)
					return !self.find_edge(ancestor,descendant).nil?
				end
				
				#Alias for edge
				def direct?(ancestor,descendant)
					return self.edge?(ancestor,descendant)
				end        
			end
			
			#Instance methods included into link model for a polymorphic DAG
			module PolyEdgeInstanceMethods
				def ancestor_type
					return self[ancestor_type_column_name]
				end
				
				def descendant_type
					return self[descendant_type_column_name]
				end
			end
			
			#Instance methods included into the link model for a nonpolymorphic DAG
			module NonPolyEdgeInstanceMethods
			end
			
			#Instance methods included into the link model for polymorphic and nonpolymorphic DAGs
			module EdgeInstanceMethods
				
				attr_accessor :do_not_perpetuate
				
				#Validations on model instance creation. Ensures no duplicate links, no cycles, and correct count and direct attributes
				def validate_on_create 
					#make sure no duplicates
					if self.class.find_link(self.source,self.sink)
						self.errors.add_to_base('Link already exists between these points')
					end
					#make sure no long cycles
					if self.class.find_link(self.sink,self.source)
						self.errors.add_to_base('Link already exists in the opposite direction')
					end
					#make sure no short cycles
					if self.sink.matches?(self.source)
						self.errors.add_to_base('Link must start and end in different places')
					end
					#make sure not impossible
					if self.direct?
						if self.count != 0
							self.errors.add_to_base('Cannot create a direct link with a count other than 0')
						end
					else
						if self.count < 1
							self.errors.add_to_base('Cannot create an indirect link with a count less than 1')
						end
					end          
				end
				
				#Validations on update. Makes sure that something changed, that not making a lonely link indirect, and count is correct.
				def validate_on_update
					unless self.changed?
						self.errors.add_to_base('No changes')
					end
					if direct_changed?
						if count_changed?
							self.errors.add_to_base('Do not manually change the count value')
						end
						if !self.direct?
							if self.count == 1
								self.errors.add_to_base('Cannot make a direct link with count 1 indirect')
							end
						end
					end
				end
				
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
					raise ActiveRecord::ActiveRecordError, 'Cannot destroy this edge' unless destroyable?
					#this triggers rewiring on destruction via perpetuate
					if self.direct?
						self[direct_column_name] = false
					end
					return true
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
					return self[ancestor_id_column_name]
				end
				
				#Id of the descendant
				def descendant_id
					return self[descendant_id_column_name]
				end
				
				#Count of the edge, ie the edge exists in X ways
				def count
					return self[count_column_name]
				end
				
				#Changes the count of the edge. DO NOT CALL THIS OUTSIDE THE PLUGIN
				def internal_count=(val)
					self[count_column_name] = val      
				end
				
				#Whether the link is direct, ie manually created
				def direct?
					return self[direct_column_name]
				end
				
				#Whether the link is an edge?
				def edge?
					return self[direct_column_name]
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
					return @source
				end
				
				#Sink (destination) of the edge, creates if necessary
				def sink
					@sink = self.class::Sink.from_edge(self) if @sink.nil?
					return @sink
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
				
				#Changes on a wire based on the count (destroy! or save!) (should not be called outside this plugin)        
				def push_associated_modification!(edge)
					raise ActiveRecord::ActiveRecordError, 'Cannot modify ourself in this way' if edge == self
					edge.do_not_perpetuate = true
					if edge.count == 0
						edge.destroy!
					else
						edge.save!
					end
				end
				
				#Updates the wiring of edges that dependent on the current one
				def rewire_crossing(above_leg,below_leg)
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
					bridging_leg = self.class.find_link(source,sink)
					if bridging_leg.nil?
						bridging_leg = self.class.new(self.class.conditions_for(source,sink))
						bridging_leg.make_indirect
						bridging_leg.internal_count = 0
					end
					bridging_leg.internal_count = bridging_leg.count + count
					return bridging_leg                     
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
						above_leg = self.class.find_link(above_source,source)
						above_bridging_leg = self.rewire_crossing(above_leg,self)
						above_bridging_legs << above_bridging_leg unless above_bridging_leg.nil? 
					end
					
					#everything beneath me tied to my source
					below_sinks.each do |below_sink|
						below_leg = self.class.find_link(sink,below_sink)
						below_bridging_leg = self.rewire_crossing(self,below_leg) 
						self.push_associated_modification!(below_bridging_leg)
						above_bridging_legs.each do |above_bridging_leg|
							long_leg = self.rewire_crossing(above_bridging_leg,below_leg)
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
end
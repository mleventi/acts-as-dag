module Dag

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
        raise ActiveRecord::ActiveRecordError, 'ERROR: Non-polymorphic graphs need to specify :node_class_name with the receiving class like belong_to'
      end
    end

    write_inheritable_attribute :acts_as_dag_options, conf
    class_inheritable_reader :acts_as_dag_options

    extend Columns
    include Columns

    #access to _changed? and _was for (edge,count) if not default
    unless direct_column_name == 'direct'
      module_eval <<-"end_eval", __FILE__, __LINE__
						def direct_changed?
							self.#{direct_column_name}_changed?
						end
						def direct_was
							self.#{direct_column_name}_was
						end
      end_eval
    end

    unless count_column_name == 'count'
      module_eval <<-"end_eval", __FILE__, __LINE__
						def count_changed?
							self.#{count_column_name}_changed?
						end
						def count_was
							self.#{count_column_name}_was
						end
      end_eval
    end

    internal_columns = [ancestor_id_column_name, descendant_id_column_name]
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

      validates ancestor_type_column_name.to_sym, :presence => true
      validates descendant_type_column_name.to_sym, :presence => true
      validates ancestor_id_column_name.to_sym, :uniqueness => {:scope => [ancestor_type_column_name, descendant_type_column_name, descendant_id_column_name]}

      scope :with_ancestor, lambda { |ancestor| where(ancestor_id_column_name => ancestor.id, ancestor_type_column_name => ancestor.class.to_s) }
      scope :with_descendant, lambda { |descendant| where(descendant_id_column_name => descendant.id, descendant_type_column_name => descendant.class.to_s) }

      scope :with_ancestor_point, lambda { |point| where(ancestor_id_column_name => point.id, ancestor_type_column_name => point.type) }
      scope :with_descendant_point, lambda { |point| where(descendant_id_column_name => point.id, descendant_type_column_name => point.type) }

      extend Polymorphic
      include Polymorphic
    else
      belongs_to :ancestor, :foreign_key => ancestor_id_column_name, :class_name => acts_as_dag_options[:node_class_name]
      belongs_to :descendant, :foreign_key => descendant_id_column_name, :class_name => acts_as_dag_options[:node_class_name]

      validates ancestor_id_column_name.to_sym, :uniqueness => {:scope => [descendant_id_column_name]}

      scope :with_ancestor, lambda { |ancestor| where(ancestor_id_column_name => ancestor.id) }
      scope :with_descendant, lambda { |descendant| where(descendant_id_column_name => descendant.id) }

      scope :with_ancestor_point, lambda { |point| where(ancestor_id_column_name => point.id) }
      scope :with_descendant_point, lambda { |point| where(descendant_id_column_name => point.id) }

      extend Standard
      include Standard
    end

    # TODO: rename? breaks when using 'where' query because :direct scope name and :direct => true parameter conflict?
    scope :direct, :conditions => {:direct => true}
    scope :indirect, :conditions => {:direct => false}

    scope :ancestor_nodes, :joins => :ancestor
    scope :descendant_nodes, :joins => :descendant

    validates ancestor_id_column_name.to_sym, :presence => true,
              :numericality => true
    validates descendant_id_column_name.to_sym, :presence => true,
              :numericality => true

    extend Edges
    include Edges

    before_destroy :destroyable!, :perpetuate
    before_save :perpetuate
    before_validation :field_check, :fill_defaults, :on => :update
    before_validation :fill_defaults, :on => :create

    include ActiveModel::Validations
    validates_with CreateCorrectnessValidator, :on => :create
    validates_with UpdateCorrectnessValidator, :on => :update


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
							raise ActiveRecord::ActiveRecordError, "ERROR: Unauthorized assignment to #{column}: it's an internal field handled by acts_as_dag code."
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
      raise ActiveRecord::ActiveRecordError, "has_dag_links must be provided with :link_class_name option"
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
									self.links_as_descendant_for_#{table_name}.empty?
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
									#{ancestor_table_names.join(' + ')}
								end
								def #{prefix}parents
									#{parent_table_names.join(' + ')}
								end
        EOL25
      else
        self.class_eval <<-EOL26
								def #{prefix}ancestors
									a = []
									#{prefix}links_as_descendant.each do |link|
										a << link.ancestor
									end
									a
								end
								def #{prefix}parents
									a = []
									#{prefix}links_as_child.each do |link|
										a << link.ancestor
									end
									a
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
                	self.links_as_ancestor_for_#{table_name}.empty?
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
									#{descendant_table_names.join(' + ')}
								end
								def #{prefix}children
									#{child_table_names.join(' + ')}
								end
        EOL35
      else
        self.class_eval <<-EOL36
								def #{prefix}descendants
									d = []
									#{prefix}links_as_ancestor.each do |link|
										d << link.descendant
									end
									d
								end
								def #{prefix}children
									d = []
									#{prefix}links_as_parent.each do |link|
										d << link.descendant
									end
									d
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
              self.#{prefix}links_as_ancestor.empty?
						end
						def #{prefix}root?
							self.#{prefix}links_as_descendant.empty?
						end
    EOL5
  end

end

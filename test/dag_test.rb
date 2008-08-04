require 'test/unit'
require 'rubygems'
gem 'activerecord', '>= 2.1'
require 'active_record'
require "#{File.dirname(__FILE__)}/../init"


ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")

#Used for basic graph link testing
class Default < ActiveRecord::Base
  acts_as_dag_links :node_class_name => 'Node'
  set_table_name 'edges'
end

#Used for polymorphic graph link testing
class Poly < ActiveRecord::Base
  acts_as_dag_links :polymorphic => true
  set_table_name 'poly_edges'
end

#Used for redefinition testing
class Redefiner < ActiveRecord::Base
  acts_as_dag_links :node_class_name => 'Redefiner',
    :direct_column => 'd', 
    :count_column => 'c',
    :ancestor_id_column => 'foo_id',
    :descendant_id_column => 'bar_id'
  set_table_name 'edges2'
end

class Node < ActiveRecord::Base
  has_dag_links :link_class_name => 'Default'
  set_table_name 'nodes'
end

class RedefNode < ActiveRecord::Base
  has_dag_links :link_class_name => 'Redefiner'
  set_table_name 'redef_nodes'
end

class AlphaNode < ActiveRecord::Base
  has_dag_links :link_class_name => 'Poly',
    :descendant_class_names => ['BetaNode','GammaNode','ZetaNode']
  set_table_name 'alpha_nodes'
end

class BetaNode < ActiveRecord::Base
  has_dag_links :link_class_name => 'Poly',
    :ancestor_class_names => ['AlphaNode','BetaNode'],
    :descendant_class_names => ['BetaNode','GammaNode','ZetaNode']
  set_table_name 'beta_nodes'
end

class GammaNode < ActiveRecord::Base
  has_dag_links :link_class_name => 'Poly',
    :ancestor_class_names => ['AlphaNode','BetaNode','GammaNode'],
    :descendant_class_names => ['GammaNode','ZetaNode']
  set_table_name 'gamma_nodes'
end

class ZetaNode < ActiveRecord::Base
  has_dag_links :link_class_name => 'Poly',
    :ancestor_class_names => ['AlphaNode','BetaNode','GammaNode']
  set_table_name 'zeta_nodes'
end


#Unit Tests for the DAG plugin
class DagTest < Test::Unit::TestCase
  
  #Setups up database in memory
  def setup
    ActiveRecord::Schema.define(:version => 1) do
    create_table :edges do |t|
      t.column :ancestor_id, :integer
      t.column :descendant_id, :integer
      t.column :direct, :boolean
      t.column :count, :integer
    end
    
    create_table :edges2 do |t|
      t.column :foo_id, :integer
      t.column :bar_id, :integer
      t.column :d, :boolean
      t.column :c, :integer
    end
    
    create_table :nodes do |t|
      t.column :name, :string
    end
    
    create_table :alpha_nodes do |t|
      t.column :name, :string
    end
    
    create_table :beta_nodes do |t|
      t.column :name, :string
    end
    
    create_table :gamma_nodes do |t|
      t.column :name, :string
    end
    
    create_table :zeta_nodes do |t|
      t.column :name, :string
    end
    
    create_table :redef_nodes do |t|
      t.column :name, :string
    end

    create_table :poly_edges do |t|
      t.column :ancestor_id, :integer
      t.column :ancestor_type, :string
      t.column :descendant_id, :integer
      t.column :descendant_type, :string
      t.column :direct, :boolean
      t.column :count, :integer
    end
  end
  end

  #Brings down database
  def teardown
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.drop_table(table)
    end
  end
  
  #Test ancestor id column default value
  def test_ancestor_id_column_default
    assert_equal 'ancestor_id', Default.acts_as_dag_options[:ancestor_id_column]
  end
  
  #Test descendant id column default value
  def test_descendant_id_column_default
    assert_equal 'descendant_id', Default.acts_as_dag_options[:descendant_id_column]
  end
  
  #Test direct column default value
  def test_direct_column_default
    assert_equal 'direct', Default.acts_as_dag_options[:direct_column]
  end
  
  #Test count column default value
  def test_count_column_default
    assert_equal 'count', Default.acts_as_dag_options[:count_column]
  end
  
  #Test ancestor type column default value
  def test_ancestor_type_column_default
    assert_equal 'ancestor_type', Poly.acts_as_dag_options[:ancestor_type_column]
  end
  
  #Test descendant type column default value
  def test_descendant_type_column_default
    assert_equal 'descendant_type', Poly.acts_as_dag_options[:descendant_type_column]
  end
  
  #Test polymorphic option default value
  def test_polymorphic_default
    assert Poly.acts_as_dag_options[:polymorphic]
    assert !Default.acts_as_dag_options[:polymorphic]
  end
  
  #more defaults here
  
  #Tests ancestor_id_column_name instance and class method
  def test_ancestor_id_column_name
    assert_equal 'ancestor_id', Default.ancestor_id_column_name
    assert_equal 'ancestor_id', Default.new.ancestor_id_column_name
  end
  
  #Tests descendant_id_column_name instance and class method
  def test_descendant_id_column_name
    assert_equal 'descendant_id', Default.descendant_id_column_name
    assert_equal 'descendant_id', Default.new.descendant_id_column_name
  end
  
  #Tests direct_column_name instance and class method
  def test_direct_column_name
    assert_equal 'direct', Default.direct_column_name
    assert_equal 'direct', Default.new.direct_column_name
  end
  
  #Tests count_column_name instance and class method
  def test_count_column_name
    assert_equal 'count', Default.count_column_name
    assert_equal 'count', Default.new.count_column_name
  end
  
  #Tests ancestor_type_column_name polymorphic instance and class method
  def test_ancestor_type_column_name
    assert_equal 'ancestor_type', Poly.ancestor_type_column_name
    assert_equal 'ancestor_type', Poly.new.ancestor_type_column_name
  end
  
  #Tests descendant_type_column_name polymorphic instance and class method
  def test_descendant_type_column_name
    assert_equal 'descendant_type', Poly.descendant_type_column_name
    assert_equal 'descendant_type', Poly.new.descendant_type_column_name
  end
  
  #Tests that count is a protected function and cannot be assigned
  def test_count_protected
    assert_raises(ActiveRecord::ActiveRecordError) { d = Default.new(:count => 1) }
    assert_raises(ActiveRecord::ActiveRecordError) { d = Default.new()
      d.count = 8 }
  end
  
  #Tests that direct is a protected function and cannot be assigned
  #def test_direct_protected
  #  assert_raises(ActiveRecord::ActiveRecordError) { d = Default.new(:direct => 1) }
  #  assert_raises(ActiveRecord::ActiveRecordError) { d = Default.new()
  #    d.direct = false }
  #end
  
  #Tests that make_direct instance method trues direct value and registers change
  def test_make_direct_method
    d = Default.new
    assert !d.direct_changed?
    d.make_direct
    assert d.direct_changed?
    assert d.direct
  end
  
  #Tests that make_indirect instance method falses direct value and registers change
  def test_make_indirect_method
    d = Default.new
    assert !d.direct_changed?
    d.make_indirect
    assert d.direct_changed?
    assert !d.direct
  end
  
  #Tests that changes register initial settings
  def test_direct_changed_init_pass_in
    d = Default.new(:direct => true)
    assert d.direct_changed?
  end
  #Tests that endpoint construction works
  def test_make_endpoint
    a = Node.create!
    p = Default::EndPoint.from(a)
    assert p.matches?(a)
  end
  
  #Tests that polymorphic endpoint construction works
  def test_make_endpoint_poly
    a = AlphaNode.create!
    p = Poly::EndPoint.from(a)
    assert p.matches?(a)
  end
  
  #Tests that source is correct
  def test_source_method
    a = Node.create!
    b = Node.create!
    edge = Default.new(:ancestor => a, :descendant => b)
    s = edge.source
    assert s.matches?(a)
  end
  
  #Tests that sink is correct
  def test_sink_method
    a = Node.create!
    b = Node.create!
    edge = Default.new(:ancestor => a, :descendant => b)
    s = edge.sink
    assert s.matches?(b)
  end
  
  #Tests that source is correct for polymorphic graphs
  def test_source_method_poly
    a = AlphaNode.create!
    b = AlphaNode.create!
    edge = Poly.new(:ancestor => a, :descendant => b)
    s = edge.source
    assert s.matches?(a)
  end
  
  #Tests that sink is correct for polymorphic graphs
  def test_sink_method_poly
    a = AlphaNode.create!
    b = AlphaNode.create!
    edge = Poly.new(:ancestor => a, :descendant => b)
    s = edge.sink
    assert s.matches?(b)
  end
  
  #Tests that source is correct when created from a model
  def test_source_method_on_resource
    a = Node.create!
    s = Default::Source.from(a)
    assert s.matches?(a)
  end
  
  #Tests that sink is correct when created from a model
  def test_sink_method_on_resource
    a = Node.create!
    s = Default::Source.from(a)
    assert s.matches?(a)
  end
  
  #Tests that source is correct when created from a model for a polymorphic graph
  def test_source_method_on_resource_poly
    a = AlphaNode.create!
    s = Poly::Source.from(a)
    assert s.matches?(a)
  end
  
  #Tests that sink is correct when created from a model for a polymorphic graph
  def test_sink_method_on_resource_poly
    a = AlphaNode.create!
    s = Poly::Source.from(a)
    assert s.matches?(a)
  end
  
  #Tests that class method for build works
  def test_build_lonely_edge
    a = Node.create!
    b = Node.create!
    e = Default.build_edge(a,b)
    assert e.source.matches?(a)
    assert e.sink.matches?(b)
  end
  
  #Tests that create_edge works
  def test_create_lonely_edge
    a = Node.create!
    b = Node.create!
    e = Default.create_edge(a,b)
    assert e
  end
  
  #Tests that create_edge! works
  def test_create_exla_lonely_edge
    a = Node.create!
    b = Node.create!
    e = Default.create_edge!(a,b)
    assert_equal e.ancestor, a
    assert_equal e.descendant, b
  end
  
  #Tests that find edge works
  def test_find_lonely_edge
    a = Node.create!
    b = Node.create!
    e = Default.create_edge(a,b)
    e = Default.find_edge(a,b)
    assert_equal e.ancestor, a
    assert_equal e.descendant, b
  end
  
  #Tests that find link works and find_edge rejects indirects
  def test_find_lonely_link
    a = Node.create!
    b = Node.create!
    e = Default.create_edge(a,b)
    e = Default.find_link(a,b)
    assert_equal e.ancestor, a
    assert_equal e.descendant, b
  end
  
  #Tests that we catch links that would be duplicated on creation
  def test_validation_on_create_duplication_catch
    a = Node.create!
    b = Node.create!
    e = Default.create_edge(a,b)
    e2 = Default.create_edge(a,b)
    assert !e2
    assert_raises(ActiveRecord::RecordInvalid) { e3 = Default.create_edge!(a,b) }
  end
  
  #Tests that we catch reversed links on creation (cycles)
  def test_validation_on_create_reverse_catch
    a = Node.create!
    b = Node.create!
    e = Default.create_edge(a,b)
    e2 = Default.create_edge(b,a)
    assert !e2
    assert_raises(ActiveRecord::RecordInvalid) { e3 = Default.create_edge!(b,a) }
  end
  
  #Tests that we catch self to self links on creation (self cycles)
  def test_validation_on_create_short_cycle_catch
    a = Node.create!
    b = Node.create!
    e = Default.create_edge(a,a)
    assert !e
    assert_raises(ActiveRecord::RecordInvalid) { e = Default.create_edge!(a,a) }
  end
  
  #Tests that a direct edge with 1 count cannot be made indirect on update
  def test_validation_on_update_indirect_catch
    a = Node.create!
    b = Node.create!
    e = Default.create_edge!(a,b)
    e.make_indirect
    assert !e.save
    assert_raises(ActiveRecord::RecordInvalid) { e.save! }
  end
  
  #Tests that nochanges fails save and save!
  def test_validation_on_update_no_change_catch
    a = Node.create!
    b = Node.create!
    e = Default.create_edge!(a,b)
    assert !e.save
    assert_raises(ActiveRecord::RecordInvalid) { e.save! }
  end
  
  #Tests that destroyable? works as required
  def tests_destroyable
    a = Node.create!
    b = Node.create!
    e = Default.create_edge!(a,b)
    assert e.destroyable?
    c = Node.create!
    f = Default.create_edge!(b,c)
    assert !Default.find_link(a,c).destroyable?
  end
  
  #Tests that destroy link works
  def tests_destroy_link
    a = Node.create!
    b = Node.create!
    e = Default.create_edge!(a,b)
    e.destroy
    assert Default.find_edge(a,b).nil?
    e = Default.create_edge!(a,b)
    c = Node.create!
    f = Default.create_edge!(b,c)
    assert_raises(ActiveRecord::ActiveRecordError) { Default.find_link(a,c).destroy }
  end
  
  #Tests the balancing of a graph in the transitive simple case
  def test_create_pair_link_transitive
    a = Node.create!
    b = Node.create!
    c = Node.create!
    e = Default.create_edge!(a,b)
    f = Default.create_edge!(b,c)
    g = Default.find_link(a,c)
    h = Default.find_edge(a,c)
    assert_equal g.ancestor, a
    assert_equal g.descendant, c
    assert_nil h
  end
  
  #Tests the ability to make an indirect link direct
  def test_make_direct_link
    a = Node.create!
    b = Node.create!
    c = Node.create!
    e = Default.create_edge!(a,b)
    f = Default.create_edge!(b,c)
    g = Default.find_link(a,c)
    g.make_direct
    g.save!
    assert_equal true, g.direct?
    assert_equal 2, g.count
  end
  
  #Tests the ability to make a direct link indirect
  def test_make_indirect_link
    a = Node.create!
    b = Node.create!
    c = Node.create!
    e = Default.create_edge!(a,b)
    f = Default.create_edge!(b,c)
    g = Default.find_link(a,c)
    g.make_direct
    g.save!
    g.make_indirect
    g.save!
    assert_equal false, g.direct?
    assert_equal 1, g.count
  end
  
  #Tests advanced transitive cases for chain graph rebalancing
  def test_create_chain_disjoint
    a = Node.create!
    b = Node.create!
    c = Node.create!
    d = Node.create!
    e = Default.create_edge!(a,b)
    f = Default.create_edge!(c,d)
    g = Default.create_edge!(b,c)
    #a to c
    test = Default.find_link(a,c)
    testnil = Default.find_edge(a,c)
    assert_equal test.ancestor, a
    assert_equal test.descendant, c
    assert_nil testnil
    #a to d
    test = Default.find_link(a,d)
    testnil = Default.find_edge(a,d)
    assert_equal test.ancestor, a
    assert_equal test.descendant, d
    assert_nil testnil
    #b to d
    test = Default.find_link(b,d)
    testnil = Default.find_edge(b,d)
    assert_equal test.ancestor, b
    assert_equal test.descendant, d
    assert_nil testnil
  end
  
  #Tests class method connect
  def test_manual_connect_lonely_edge
    a = Node.create!
    b = Node.create!
    e = Default.connect!(a,b)
    e2 = Default.find_edge(a,b)
    assert e2.direct?
    assert_equal 1, e2.count
    assert_equal e,e2
    assert_equal e2.ancestor, a
    assert_equal e2.descendant, b
  end
  
  #Tests simple indirect link creation
  def test_auto_simple_cross
    a = Node.create!
    b = Node.create!
    c = Node.create!
    e = Default.connect(a,b)
    e2 = Default.connect(b,c)
    indirect = Default.find_link(a,c)
    assert !indirect.nil?
    assert !indirect.direct?
    assert_equal 1, indirect.count
    assert_equal a, indirect.ancestor
    assert_equal c, indirect.descendant 
  end
  
  ##########################
  #TESTS FOR has_dag_links #
  ##########################
  
  #Tests has_many links_as_ancestor
  def test_has_many_links_as_ancestor
    a = Node.create!
    b = Node.create!
    e = a.links_as_ancestor.build
    e.descendant = b
    e.save!
    assert_equal e.ancestor, a
    assert_equal e.descendant, b
  end
  
  #Tests has_many links_as_descendant
  def test_has_many_links_as_descendant
    a = Node.create!
    b = Node.create!
    e = b.links_as_descendant.build
    e.ancestor = a
    e.save!
    assert_equal e.ancestor, a
    assert_equal e.descendant, b
  end
  
  #Tests has_many links_as_parent
  def test_has_many_links_as_parent
    a = Node.create!
    b = Node.create!
    e = a.links_as_parent.build
    e.descendant = b
    e.save!
    assert_equal e.ancestor, a
    assert_equal e.descendant, b
  end
  
  #Tests has_many links_as_child
  def test_has_many_links_as_child
    a = Node.create!
    b = Node.create!
    e = b.links_as_child.build
    e.ancestor = a
    e.save!
    assert_equal e.ancestor, a
    assert_equal e.descendant, b
  end
  
  #Tests has_many descendants
  def test_has_many_descendants
    a = Node.create!
    b = Node.create!
    a.descendants << b
    e = Default.find_link(a,b)
    assert !e.nil? 
  end
  
  #Tests has_many ancestors
  def test_has_many_ancestors
    a = Node.create!
    b = Node.create!
    b.ancestors << a
    e = Default.find_link(a,b)
    assert !e.nil? 
  end
  
  #Tests has_many children
  def test_has_many_children
    a = Node.create!
    b = Node.create!
    a.children << b
    e = Default.find_link(a,b)
    assert !e.nil? 
  end
  
  #Tests has_many parents
  def test_has_many_parents
    a = Node.create!
    b = Node.create!
    b.parents << a
    e = Default.find_link(a,b)
    assert !e.nil? 
  end 
  
  #Tests leaf? instance method
  def test_leaf_instance_method
    a = Node.create!
    assert a.leaf?
    b = Node.create!
    a.children << b
    a.reload
    b.reload
    assert !a.leaf?
    assert b.leaf?
  end
  
  #Tests root? instance method
  def test_root_instance_method
    a = Node.create!
    b = Node.create!
    assert b.root?
    a.children << b
    a.reload
    b.reload
    assert !b.root?
    assert a.root?
  end
  
  #Tests has_many links_as_ancestor
  def test_has_many_links_as_ancestor_poly
    a = BetaNode.create!
    b = BetaNode.create!
    e = a.links_as_ancestor.build
    e.descendant = b
    e.save!
    assert_equal e.ancestor, a
    assert_equal e.descendant, b
  end
  
  #Tests has_many links_as_descendant
  def test_has_many_links_as_descendant_poly
    a = BetaNode.create!
    b = BetaNode.create!
    e = b.links_as_descendant.build
    e.ancestor = a
    e.save!
    assert_equal e.ancestor, a
    assert_equal e.descendant, b
  end
  
  #Tests has_many links_as_parent
  def test_has_many_links_as_parent_poly
    a = BetaNode.create!
    b = BetaNode.create!
    e = a.links_as_parent.build
    e.descendant = b
    e.save!
    assert_equal e.ancestor, a
    assert_equal e.descendant, b
  end
  
  #Tests has_many links_as_child
  def test_has_many_links_as_child_poly
    a = BetaNode.create!
    b = BetaNode.create!
    e = b.links_as_child.build
    e.ancestor = a
    e.save!
    assert_equal e.ancestor, a
    assert_equal e.descendant, b
  end
  
  #Tests leaf? instance method
  def test_leaf_instance_method_poly
    a = BetaNode.create!
    assert a.leaf?
    b = BetaNode.create!
    a.child_beta_nodes << b
    a.reload
    b.reload
    assert !a.leaf?
    assert b.leaf?
  end
  
  #Tests root? instance method
  def test_root_instance_method_poly
    a = BetaNode.create!
    b = BetaNode.create!
    assert b.root?
    a.child_beta_nodes << b
    a.reload
    b.reload
    assert !b.root?
    assert a.root?
  end
  
  #Tests has_many links_as_ancestor_for_*
  def test_has_many_links_as_ancestor_for
    a = AlphaNode.create!
    b = BetaNode.create!
    e = a.links_as_ancestor_for_beta_nodes.build
    e.descendant = b
    e.save!
    assert_equal e.ancestor, a
    assert_equal e.descendant, b
  end
  
  #Tests has_many links_as_descendant_for_*
  def test_has_many_links_as_descendant_for
    a = AlphaNode.create!
    b = BetaNode.create!
    e = b.links_as_descendant_for_alpha_nodes.build
    e.ancestor = a
    e.save!
    assert_equal e.ancestor, a
    assert_equal e.descendant, b
  end
  
  #Tests has_many links_as_parent_for_*
  def test_has_many_links_as_parent_for
    a = AlphaNode.create!
    b = BetaNode.create!
    e = a.links_as_parent_for_beta_nodes.build
    e.descendant = b
    e.save!
    assert_equal e.ancestor, a
    assert_equal e.descendant, b
  end
  
  #Tests has_many links_as_child_for_*
  def test_has_many_links_as_child_for
    a = AlphaNode.create!
    b = BetaNode.create!
    e = b.links_as_child_for_alpha_nodes.build
    e.ancestor = a
    e.save!
    assert_equal e.ancestor, a
    assert_equal e.descendant, b
  end
  
  #Tests has_many descendant_type
  def test_has_many_descendant_dvds
    a = AlphaNode.create!
    b = BetaNode.create!
    a.descendant_beta_nodes << b
    e = Poly.find_link(a,b)
    assert !e.nil? 
  end
  
  #Tests has_many ancestor_type
  def test_has_many_ancestor_dvds
    a = AlphaNode.create!
    b = BetaNode.create!
    b.ancestor_alpha_nodes << a
    e = Poly.find_link(a,b)
    assert !e.nil? 
  end
  
  #Tests has_many child_dvds
  def test_has_many_child_dvds
    a = AlphaNode.create!
    b = BetaNode.create!
    a.child_beta_nodes << b
    e = Poly.find_link(a,b)
    assert !e.nil? 
  end
  
  #Tests has_many parents
  def test_has_many_parent_dvds
    a = AlphaNode.create!
    b = BetaNode.create!
    b.parent_alpha_nodes << a
    e = Poly.find_link(a,b)
    assert !e.nil? 
  end 
  
  #Tests leaf_for_*? instance method
  def test_leaf_for_instance_method
    a = BetaNode.create!
    b = BetaNode.create!
    assert a.leaf_for_beta_nodes?
    a.ancestor_beta_nodes << b
    a.reload
    b.reload
    assert !b.leaf_for_beta_nodes?
  end
  
  #Tests root_for_*? instance method
  def test_root_for_instance_method
    a = BetaNode.create!
    b = BetaNode.create!
    assert a.root_for_beta_nodes?
    a.descendant_beta_nodes << b
    a.reload
    b.reload
    assert !b.root_for_beta_nodes?
  end
end
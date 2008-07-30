require 'test/unit'
require 'rubygems'
gem 'activerecord', '>= 1.15.4.7794'
require 'active_record'
require "#{File.dirname(__FILE__)}/../init"




ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")

class Node < ActiveRecord::Base
  set_table_name 'alpha_nodes'
end

class BetaNode < ActiveRecord::Base
  set_table_name 'beta_nodes'
end

class GammaNode < ActiveRecord::Base
  set_table_name 'gamma_nodes'
end

class Default < ActiveRecord::Base
  acts_as_dag_links :for => 'Node'
  set_table_name 'edges'
end


class Poly < ActiveRecord::Base
  acts_as_dag_links :polymorphic => true, :for => {'Node' => ['BetaNode','GammaNode']}
  set_table_name 'poly_edges'
end

class Redefiner < ActiveRecord::Base
  acts_as_dag_links :for => 'Node', 
    :direct_column => 'd', 
    :count_column => 'c',
    :ancestor_id_column => 'foo_id',
    :descendent_id_column => 'bar_id'
  set_table_name 'edges2'
end

class DagTest < Test::Unit::TestCase
  
  def setup
    ActiveRecord::Schema.define(:version => 1) do
    create_table :edges do |t|
      t.column :ancestor_id, :integer
      t.column :descendent_id, :integer
      t.column :direct, :boolean
      t.column :count, :integer
    end
    
    create_table :edges2 do |t|
      t.column :foo_id, :integer
      t.column :bar_id, :integer
      t.column :d, :boolean
      t.column :c, :integer
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

    create_table :poly_edges do |t|
      t.column :ancestor_id, :integer
      t.column :ancestor_type, :string
      t.column :descendent_id, :integer
      t.column :descendent_type, :string
      t.column :direct, :boolean
      t.column :count, :integer
    end
  end
  (1..10).each {|counter| Node.create!(:name => "Node #{counter}")}
  end

  def teardown
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.drop_table(table)
    end
  end
  
  def test_ancestor_id_column_default
    assert_equal 'ancestor_id', Default.acts_as_dag_options[:ancestor_id_column]
  end
  
  def test_descendent_id_column_default
    assert_equal 'descendent_id', Default.acts_as_dag_options[:descendent_id_column]
  end
  
  def test_direct_column_default
    assert_equal 'direct', Default.acts_as_dag_options[:direct_column]
  end
  
  def test_count_column_default
    assert_equal 'count', Default.acts_as_dag_options[:count_column]
  end
  
  def test_ancestor_type_column_default
    assert_equal 'ancestor_type', Poly.acts_as_dag_options[:ancestor_type_column]
  end
  
  def test_descendent_type_column_default
    assert_equal 'descendent_type', Poly.acts_as_dag_options[:descendent_type_column]
  end
  
  def test_polymorphic_default
    assert Poly.acts_as_dag_options[:polymorphic]
    assert !Default.acts_as_dag_options[:polymorphic]
  end
  
  #more defaults here
  
  def test_ancestor_id_column_name
    assert_equal 'ancestor_id', Default.ancestor_id_column_name
    assert_equal 'ancestor_id', Default.new.ancestor_id_column_name
  end
  
  def test_descendent_id_column_name
    assert_equal 'descendent_id', Default.descendent_id_column_name
    assert_equal 'descendent_id', Default.new.descendent_id_column_name
  end
  
  def test_direct_column_name
    assert_equal 'direct', Default.direct_column_name
    assert_equal 'direct', Default.new.direct_column_name
  end
  
  def test_count_column_name
    assert_equal 'count', Default.count_column_name
    assert_equal 'count', Default.new.count_column_name
  end
  
  def test_ancestor_type_column_name
    assert_equal 'ancestor_type', Poly.ancestor_type_column_name
    assert_equal 'ancestor_type', Poly.new.ancestor_type_column_name
  end
  
  def test_descendent_type_column_name
    assert_equal 'descendent_type', Poly.descendent_type_column_name
    assert_equal 'descendent_type', Poly.new.descendent_type_column_name
  end
  
  def test_count_protected
    assert_raises(ActiveRecord::ActiveRecordError) { d = Default.new(:count => 1) }
    assert_raises(ActiveRecord::ActiveRecordError) { d = Default.new()
      d.count = 8 }
  end
  
  def test_direct_protected
    assert_raises(ActiveRecord::ActiveRecordError) { d = Default.new(:direct => 1) }
    assert_raises(ActiveRecord::ActiveRecordError) { d = Default.new()
      d.direct = false }
  end
  
  def test_make_direct_method
    d = Default.new
    assert !d.direct_changed?
    d.make_direct
    assert d.direct_changed?
    assert d.direct
  end
  
  def test_make_indirect_method
    d = Default.new
    assert !d.direct_changed?
    d.make_indirect
    assert d.direct_changed?
    assert !d.direct
  end
  
  def test_make_endpoint
    a = Node.create!
    p = Default::EndPoint.from(a)
    assert p.matches?(a)
  end
  
  def test_make_endpoint_poly
    a = Node.create!
    p = Poly::EndPoint.from(a)
    assert p.matches?(a)
  end
  
  def test_source_method
    a = Node.create!
    b = Node.create!
    edge = Default.new(:ancestor => a, :descendent => b)
    s = edge.source
    assert s.matches?(a)
  end
  
  def test_sink_method
    a = Node.create!
    b = Node.create!
    edge = Default.new(:ancestor => a, :descendent => b)
    s = edge.sink
    assert s.matches?(b)
  end
  
  def test_source_method_poly
    a = Node.create!
    b = Node.create!
    edge = Poly.new(:ancestor => a, :descendent => b)
    s = edge.source
    assert s.matches?(a)
  end
  
  def test_sink_method_poly
    a = Node.create!
    b = Node.create!
    edge = Poly.new(:ancestor => a, :descendent => b)
    s = edge.sink
    assert s.matches?(b)
  end
  
  def test_source_method_on_resource
    a = Node.create!
    s = Default::Source.from(a)
    assert s.matches?(a)
  end
  
  def test_sink_method_on_resource
    a = Node.create!
    s = Default::Source.from(a)
    assert s.matches?(a)
  end
  
  def test_source_method_on_resource_poly
    a = Node.create!
    s = Poly::Source.from(a)
    assert s.matches?(a)
  end
  
  def test_sink_method_on_resource_poly
    a = Node.create!
    s = Poly::Source.from(a)
    assert s.matches?(a)
  end
  
  def test_build_lonely_edge
    a = Node.create!
    b = Node.create!
    e = Default.build_edge(a,b)
    assert e.source.matches?(a)
    assert e.sink.matches?(b)
  end
  
  def test_create_lonely_edge
    a = Node.create!
    b = Node.create!
    e = Default.create_edge(a,b)
    assert e
  end
  
  def test_create_exla_lonely_edge
    a = Node.create!
    b = Node.create!
    e = Default.create_edge!(a,b)
    assert_equal e.ancestor, a
    assert_equal e.descendent, b
  end
  
  def test_find_lonely_edge
    a = Node.create!
    b = Node.create!
    e = Default.create_edge(a,b)
    e = Default.find_edge(a,b)
    assert_equal e.ancestor, a
    assert_equal e.descendent, b
  end
  
  def test_find_lonely_link
    a = Node.create!
    b = Node.create!
    e = Default.create_edge(a,b)
    e = Default.find_link(a,b)
    assert_equal e.ancestor, a
    assert_equal e.descendent, b
  end
  
  def test_validation_on_create_duplication_catch
    a = Node.create!
    b = Node.create!
    e = Default.create_edge(a,b)
    e2 = Default.create_edge(a,b)
    assert !e2
    assert_raises(ActiveRecord::RecordInvalid) { e3 = Default.create_edge!(a,b) }
  end
  
  def test_validation_on_create_reverse_catch
    a = Node.create!
    b = Node.create!
    e = Default.create_edge(a,b)
    e2 = Default.create_edge(b,a)
    assert !e2
    assert_raises(ActiveRecord::RecordInvalid) { e3 = Default.create_edge!(b,a) }
  end
  
  def test_validation_on_create_short_cycle_catch
    a = Node.create!
    b = Node.create!
    e = Default.create_edge(a,a)
    assert !e
    assert_raises(ActiveRecord::RecordInvalid) { e = Default.create_edge!(a,a) }
  end
  
  def test_validation_on_update_indirect_catch
    a = Node.create!
    b = Node.create!
    e = Default.create_edge!(a,b)
    e.make_indirect
    assert !e.save
    assert_raises(ActiveRecord::RecordInvalid) { e.save! }
  end
  
  def test_validation_on_update_no_change_catch
    a = Node.create!
    b = Node.create!
    e = Default.create_edge!(a,b)
    assert !e.save
    assert_raises(ActiveRecord::RecordInvalid) { e.save! }
  end
  
  def tests_destroyable
    a = Node.create!
    b = Node.create!
    e = Default.create_edge!(a,b)
    assert e.destroyable?
    c = Node.create!
    f = Default.create_edge!(b,c)
    assert !Default.find_link(a,c).destroyable?
  end
  
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
  
  def test_create_pair_link_transitive
    a = Node.create!
    b = Node.create!
    c = Node.create!
    e = Default.create_edge!(a,b)
    f = Default.create_edge!(b,c)
    g = Default.find_link(a,c)
    h = Default.find_edge(a,c)
    assert_equal g.ancestor, a
    assert_equal g.descendent, c
    assert_nil h
  end
  
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
    assert_equal test.descendent, c
    assert_nil testnil
    #a to d
    test = Default.find_link(a,d)
    testnil = Default.find_edge(a,d)
    assert_equal test.ancestor, a
    assert_equal test.descendent, d
    assert_nil testnil
    #b to d
    test = Default.find_link(b,d)
    testnil = Default.find_edge(b,d)
    assert_equal test.ancestor, b
    assert_equal test.descendent, d
    assert_nil testnil
  end
  
  def test_manual_connect_lonely_edge
    a = Node.create!
    b = Node.create!
    e = Default.connect!(a,b)
    e2 = Default.find_edge(a,b)
    assert e2.direct?
    assert_equal 1, e2.count
    assert_equal e,e2
    assert_equal e2.ancestor, a
    assert_equal e2.descendent, b
  end
  
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
    assert_equal c, indirect.descendent 
  end
  
  def test_has_many_injection_ancestor
    a = Node.create!
    b = Node.create!
    e = a.links_as_ancestor.build
    e.descendent = b
    e.save!
    assert_equal e.ancestor, a
    assert_equal e.descendent, b
  end
  
  def test_has_many_injection_descendent
    a = Node.create!
    b = Node.create!
    e = b.links_as_descendent.build
    e.ancestor = a
    e.save!
    assert_equal e.ancestor, a
    assert_equal e.descendent, b
  end
  
  def test_has_many_through_injection_ancestor
    a = Node.create!
    b = Node.create!
    a.descendents << b
    #assert !Default.first.nil?
    #assert_equal Default.first.ancestor, a
    #assert_equal Default.first.descendent, b 
  end
  
  
  
  
  
  #def test_manual_create_lonely_edge
  #  a = Node.create!
  #  b = Node.create!
  #  edge = Default.new(:ancestor => a, :descendent => b)
  #  edge.save!
  #  assert_equal a.links_as_ancestor.first, edge
  #  assert_equal b.links_as_descendent.first, edge
  #  assert_equal 1, edge.count
  #  assert_equal true, edge.direct?
  #end
    
    
    
    
  
  #more column names

  #def test_ancestor_id_column_protected_from_assignment_on_update
  #  assert_raises(ActiveRecord::ActiveRecordError) { d = Default.new(:ancestor_id => 1, :descendent_id => 2) }
  #end
  #
  #def test_descendent_id_column_protected_from_assignment_on_update
  #  assert_raises(ActiveRecord::ActiveRecordError) { Default.new.descendent_id = 1 }
  #end
  #
  #def test_ancestor_type_column_protected_from_assignment_on_update
  #  assert_raises(ActiveRecord::ActiveRecordError) { Poly.new.ancestor_type = 'A' }
  #end
  #
  #def test_descendent_type_column_protected_from_assignment_on_update
  #  assert_raises(ActiveRecord::ActiveRecordError) { Poly.new.descendent_type = 'A' }
  #end
  
  #def test_columns_protected_on_initialize
  #  c = Default.new(:count => 4, :direct => false)
  #  assert_nil c.count
  #  assert_nil c.direct
    #r = Redefiner.new(:c => 4, :d => false)
    #assert_nil r.count
    #assert_nil r.direct
  #end
  
  #changed and was

  
  #def test_for_class_method
  #  
  #end
  
  
  
  #more protections  
end
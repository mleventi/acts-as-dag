require "#{File.dirname(__FILE__)}/lib/active_record/acts/dag"
ActiveRecord::Base.send(:include, ActiveRecord::Acts::Dag)
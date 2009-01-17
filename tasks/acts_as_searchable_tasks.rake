require File.expand_path("../lib/estraier_admin", File.dirname(__FILE__))

namespace :search do
  desc "Clears HE Index"
  task :clear => :environment do
    raise "Pass a searchable model with MODEL=" unless ENV['MODEL']
    ENV['MODEL'].constantize.clear_index!
  end

  desc "Reindexes all model attributes"
  task :reindex => :environment do
    raise "Pass a searchable model with MODEL=" unless ENV['MODEL']
    model_class = ENV['MODEL'].constantize
    reindex = lambda { model_class.reindex! }
    if ENV['INCLUDE']
      model_class.with_scope :find => { :include => ENV['INCLUDE'].split(',').collect { |i| i.strip.to_sym } } do
        reindex.call
      end
    else
      reindex.call
    end
  end

  namespace :node do
    desc "Create HE node"
    task :create => :environment do
      raise "Pass a searchable model with MODEL=" unless ENV['MODEL']
      model_class = ENV['MODEL'].constantize
      admin.create_node(model_class.search_backend.node_name)
    end

    desc "Delete HE node"
    task :delete => :environment do
      raise "Pass a searchable model with MODEL=" unless ENV['MODEL']
      model_class = ENV['MODEL'].constantize
      admin.delete_node(model_class.search_backend.node_name)
    end

    def admin
      EstraierAdmin.new(ActiveRecord::Base.configurations[RAILS_ENV]["estraier"])
    end
  end

  namespace :server do
    desc "initialize HyperEstraier index directory on localhost"
    task :init do
      system(estmaster, 'init', index_dir) unless File.directory?(index_dir)
    end

    desc "start HyperEstraier server on loaclhost"
    task :start => [:init] do
      $stderr.puts "starting HyperEstraier server..."
      system(estmaster, 'start', '-bg', index_dir)
    end

    desc "stop HyperEstraier server on localhost"
    task :stop => [:init] do
      $stderr.puts "stopping HyperEstraier server..."
      system(estmaster, 'stop', index_dir)
    end

    def estmaster
      ENV['COMMAND'] || 'estmaster'
    end

    def index_dir
      ENV['SEARCH_INDEX_DIR'] || File.expand_path("tmp/fulltext_index", Dir.pwd)
    end
  end
end
require 'rake/rdoctask'
require 'spec'

desc 'Default: run specs_all.'
task :default => :spec_all

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new {|t| t.spec_opts = ['--color']}

desc "Run specs both AR-latest and AR-2.0.x"
task :spec_all do
  ar20xs = (::Gem.source_index.find_name("activerecord", "<2.1") & \
            ::Gem.source_index.find_name("activerecord", ">=2.0"))
  if ar20xs.empty?
    Rake::Task[:spec].invoke
  else
    ar20 = ar20xs.sort_by(&:version).last
    system("rake spec")
    system("rake spec AR=#{ar20.version}")
  end
end

desc 'Generate documentation for the acts_as_searchable plugin.'
Rake::RDocTask.new(:rdoc) do |doc|
  doc.rdoc_dir = 'rdoc'
  doc.title    = 'SearchDo'
  doc.options << '--line-numbers' << '--inline-source'
  doc.rdoc_files.include('README.rdoc')
  doc.rdoc_files.include('lib/**/*.rb')
end

begin
  require 'jeweler'
  project_name = 'search_do'

  Jeweler::Tasks.new do |gem|
    gem.name = project_name
    gem.summary = "AR: Hyperestraier integration"
    gem.email = "moronatural@gmail.com"
    gem.homepage = "http://github.com/grosser/#{project_name}"
    gem.authors = ["MOROHASHI Kyosuke"]
  end

  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler, or one of its dependencies, is not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end
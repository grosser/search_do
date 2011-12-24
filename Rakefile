require 'rdoc/task'

task :spec do
  sh "bundle exec spec spec"
end

task :default do
  sh "RAILS=2.3.14 && (bundle || bundle install) && bundle exec rake spec"
  sh "RAILS=3.0.12 && (bundle || bundle install) && bundle exec rake spec"
  sh "RAILS=3.1.3 && (bundle || bundle install) && bundle exec rake spec"
  sh "git checkout Gemfile.lock"
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
    gem.authors = ["MOROHASHI Kyosuke", "Michael Grosser"]
  end

  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler, or one of its dependencies, is not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end
require 'rubygems'
require 'rake/rdoctask'
require 'rake/packagetask'
require 'rake/gempackagetask'
require 'rake/testtask'
require 'spec'

# require 'rake/contrib/rubyforgepublisher'

PKG_NAME      = 'search_do'
PKG_VERSION   = '0.1.9'
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"
# RUBY_FORGE_PROJECT = 'ar-searchable'
# RUBY_FORGE_USER    = 'scoop'

desc 'Default: run specs_all.'
task :default => :spec_all

desc "Run all specs in spec directory"
task :spec do |t|
  options = "--colour --format progress --loadby --reverse"
  files = FileList['spec/**/*_spec.rb']
  system("spec #{options} #{files}")
end

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
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'ActsAsSearchable'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

spec = Gem::Specification.new do |s|
  s.name            = PKG_NAME
  s.version         = PKG_VERSION
  s.platform        = Gem::Platform::RUBY
  s.summary         = "adds fulltext searching capabilities, currently Hyper Estraier backend is supported."
  s.files           = FileList["{lib,recipes,tasks,spec,rails}/**/*"].to_a + %w(README MIT-LICENSE CHANGELOG)
  s.require_path    = 'lib'
  s.has_rdoc        = true
  s.test_files      = Dir['spec/**/*_spec.rb']
  s.author          = "MOROHASHI Kyosuke"
  s.email           = "moronatural@gmail.com"
  s.homepage        = "http://github.com/moro/search_do"
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true
end

desc "update #{PKG_NAME}.gemspec"
task "gemspec" do
  fname = File.expand_path("#{PKG_NAME}.gemspec", File.dirname(__FILE__))
  File.open(fname, "w"){|f| f.puts spec.to_ruby }
end

=begin
desc "Publish the API documentation"
task :pdoc => [:rdoc] do
  Rake::RubyForgePublisher.new(RUBY_FORGE_PROJECT, RUBY_FORGE_USER).upload
end

desc 'Publish the gem and API docs'
task :publish => [:pdoc, :rubyforge_upload]

desc "Publish the release files to RubyForge."
task :rubyforge_upload => :package do
  files = %w(gem tgz).map { |ext| "pkg/#{PKG_FILE_NAME}.#{ext}" }

  if RUBY_FORGE_PROJECT then
    require 'net/http'
    require 'open-uri'

    project_uri = "http://rubyforge.org/projects/#{RUBY_FORGE_PROJECT}/"
    project_data = open(project_uri) { |data| data.read }
    group_id = project_data[/[?&]group_id=(\d+)/, 1]
    raise "Couldn't get group id" unless group_id

    # This echos password to shell which is a bit sucky
    if ENV["RUBY_FORGE_PASSWORD"]
      password = ENV["RUBY_FORGE_PASSWORD"]
    else
      print "#{RUBY_FORGE_USER}@rubyforge.org's password: "
      password = STDIN.gets.chomp
    end

    login_response = Net::HTTP.start("rubyforge.org", 80) do |http|
      data = [
        "login=Login",
        "form_loginname=#{RUBY_FORGE_USER}",
        "form_pw=#{password}"
      ].join("&")

      headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }

      http.post("/account/login.php", data, headers)
    end

    cookie = login_response["set-cookie"]
    raise "Login failed" unless cookie
    headers = { "Cookie" => cookie }

    release_uri = "http://rubyforge.org/frs/admin/?group_id=#{group_id}"
    release_data = open(release_uri, headers) { |data| data.read }
    package_id = release_data[/[?&]package_id=(\d+)/, 1]
    raise "Couldn't get package id" unless package_id

    first_file = true
    release_id = ""

    files.each do |filename|
      basename  = File.basename(filename)
      file_ext  = File.extname(filename)
      file_data = File.open(filename, "rb") { |file| file.read }

      puts "Releasing #{basename}..."

      release_response = Net::HTTP.start("rubyforge.org", 80) do |http|
        release_date = Time.now.strftime("%Y-%m-%d %H:%M")
        type_map = {
          ".zip"    => "3000",
          ".tgz"    => "3110",
          ".gz"     => "3110",
          ".gem"    => "1400"
        }; type_map.default = "9999"
        type = type_map[file_ext]
        boundary = "rubyqMY6QN9bp6e4kS21H4y0zxcvoor"

        query_hash = if first_file then
          {
            "group_id" => group_id,
            "package_id" => package_id,
            "release_name" => PKG_FILE_NAME,
            "release_date" => release_date,
            "type_id" => type,
            "processor_id" => "8000", # Any
            "release_notes" => "",
            "release_changes" => "",
            "preformatted" => "1",
            "submit" => "1"
          }
        else
          {
            "group_id" => group_id,
            "release_id" => release_id,
            "package_id" => package_id,
            "step2" => "1",
            "type_id" => type,
            "processor_id" => "8000", # Any
            "submit" => "Add This File"
          }
        end

        data = [
          "--" + boundary,
          "Content-Disposition: form-data; name=\"userfile\"; filename=\"#{basename}\"",
          "Content-Type: application/octet-stream",
          "Content-Transfer-Encoding: binary",
          "", file_data, "",
          query_hash.collect do |name, value|
            [ "--" + boundary,
              "Content-Disposition: form-data; name='#{name}'",
              "", value, "" ]
          end
          ].flatten.join("\x0D\x0A")

        release_headers = headers.merge(
          "Content-Type" => "multipart/form-data; boundary=#{boundary}"
        )

        target = first_file ? "/frs/admin/qrs.php" : "/frs/admin/editrelease.php"
        http.post(target, data, release_headers)
      end

      if first_file then
        release_id = release_response.body[/release_id=(\d+)/, 1]
        raise("Couldn't get release id") unless release_id
      end

      first_file = false
    end
  end
end
=end


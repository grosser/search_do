namespace :search do

  desc "Reindexes all model attributes"
  task :reindex do
      rake = fetch(:rake, "rake")
      rails_env = fetch(:rails_env, "production")
      run "cd #{current_path}; #{rake} RAILS_ENV=#{rails_env} search:reindex MODEL=#{ENV['MODEL']}"
  end

  namespace :node do

    desc "Create HE node"
    task :create do
      rake = fetch(:rake, "rake")
      rails_env = fetch(:rails_env, "production")
      run "cd #{current_path}; #{rake} RAILS_ENV=#{rails_env} search:node:create MODEL=#{ENV['MODEL']}"
    end

    desc "Delete HE node"
    task :delete do
      rake = fetch(:rake, "rake")
      rails_env = fetch(:rails_env, "production")
      run "cd #{current_path}; #{rake} RAILS_ENV=#{rails_env} search:node:delete MODEL=#{ENV['MODEL']}"
    end
  end
end
namespace :search do

  desc "Reindexes all model attributes"
  task :reindex do
      rake = fetch(:rake, "rake")
      rails_env = fetch(:rails_env, "production")
      run "cd #{current_path}; #{rake} RAILS_ENV=#{rails_env} search:reindex MODEL=#{ENV['MODEL']}"
  end

  namespace :node do

    desc "Create HE node"
    task :create do
      rake = fetch(:rake, "rake")
      rails_env = fetch(:rails_env, "production")
      run "cd #{current_path}; #{rake} RAILS_ENV=#{rails_env} search:node:create MODEL=#{ENV['MODEL']}"
    end

    desc "Delete HE node"
    task :delete do
      rake = fetch(:rake, "rake")
      rails_env = fetch(:rails_env, "production")
      run "cd #{current_path}; #{rake} RAILS_ENV=#{rails_env} search:node:delete MODEL=#{ENV['MODEL']}"
    end
  end
end

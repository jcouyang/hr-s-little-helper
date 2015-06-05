begin
  require 'rspec/core'
  require 'rspec/core/rake_task'
  namespace :spec do
    spec_opts = ['-f', 'progress', '--color']
    desc 'Run all spec tests'
    RSpec::Core::RakeTask.new(:spec) do |t|
      t.pattern = './spec/**/*_spec.rb'
      t.rspec_opts = spec_opts
    end
  end
rescue LoadError => e
  namespace :spec do
    desc "RSpec tasks not available (#{e})"
    task :spec do
      abort e
    end
  end
end
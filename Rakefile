task :default do
  system("rake -T")
end

desc "Run RSpec unit tests"
task :spec do
  ENV["LOG_SPEC_ORDER"] = "true"
  if ENV['verbose'] == 'true'
    sh %{rspec #{ENV['TEST'] || ENV['TESTS'] || 'spec'} -fd}
  else
    sh %{rspec #{ENV['TEST'] || ENV['TESTS'] || 'spec'}}
  end
end

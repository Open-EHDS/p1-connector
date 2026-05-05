# frozen_string_literal: true

require 'rake/testtask'

all_tests = FileList['spec/**/*_test.rb']
integration_tests = FileList['spec/p1_tool/integration/**/*_test.rb']
unit_tests = all_tests.exclude(*integration_tests)

Rake::TestTask.new do |task|
  task.libs << 'lib'
  task.libs << 'spec'
  task.test_files = all_tests
end

namespace :test do
  Rake::TestTask.new(:unit) do |task|
    task.libs << 'lib'
    task.libs << 'spec'
    task.test_files = unit_tests
  end

  Rake::TestTask.new(:integration) do |task|
    task.libs << 'lib'
    task.libs << 'spec'
    task.test_files = integration_tests
  end
end

task default: :test

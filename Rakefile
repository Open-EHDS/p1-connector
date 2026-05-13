# frozen_string_literal: true

require 'rake/testtask'
require 'shellwords'

all_tests = FileList['spec/**/*_test.rb']
integration_tests = FileList['spec/p1_tool/integration/**/*_test.rb']
unit_tests = FileList['spec/**/*_test.rb'].exclude(*integration_tests)
compose_file = File.expand_path('docker-compose.dev.yml', __dir__)

def compose_command(compose_file, *args)
  ['docker', 'compose', '-f', compose_file, *args].shelljoin
end

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

namespace :dev do
  namespace :redis do
    desc 'Start Redis from docker-compose.dev.yml'
    task :up do
      sh compose_command(compose_file, 'up', '-d', 'redis')
    end

    desc 'Stop Redis from docker-compose.dev.yml'
    task :down do
      sh compose_command(compose_file, 'down')
    end

    desc 'Show Redis container status'
    task :ps do
      sh compose_command(compose_file, 'ps')
    end

    desc 'Tail Redis logs'
    task :logs do
      sh compose_command(compose_file, 'logs', '-f', 'redis')
    end
  end
end

task default: :test

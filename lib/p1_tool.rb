# frozen_string_literal: true

require 'bundler/setup'
require_relative 'p1_tool/env_loader'

P1Tool::EnvLoader.load!

app_env = ENV.fetch('APP_ENV', 'development')

require 'pry' if %w[development test].include?(app_env)

require_relative 'p1_tool/version'
require_relative 'p1_tool/errors'
require_relative 'p1_tool/adapters'
require_relative 'p1_tool/core'
require_relative 'p1_tool/xml'
require_relative 'p1_tool/gateways'
require_relative 'p1_tool/application'
require_relative 'p1_tool/runtime'
require_relative 'p1_tool/jobs'

module P1Tool
  CLI = Application::CLI
end

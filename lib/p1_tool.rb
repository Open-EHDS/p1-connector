# frozen_string_literal: true

require "bundler/setup"

app_env = ENV.fetch("APP_ENV", "development")

require "pry" if %w[development test].include?(app_env)

require_relative "p1_tool/version"
require_relative "p1_tool/errors"
require_relative "p1_tool/adapters/file_system"
require_relative "p1_tool/core/configuration_schema"
require_relative "p1_tool/core/configuration_loader"
require_relative "p1_tool/core/input_schema"
require_relative "p1_tool/core/input_validator"
require_relative "p1_tool/application/operations/hello_world"
require_relative "p1_tool/application/dispatcher"
require_relative "p1_tool/runtime/workspace"
require_relative "p1_tool/application/cli"

module P1Tool
  CLI = Application::CLI
end

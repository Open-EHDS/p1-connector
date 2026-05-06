# frozen_string_literal: true

require 'bundler/setup'
require_relative 'p1_tool/env_loader'

P1Tool::EnvLoader.load!

app_env = ENV.fetch('APP_ENV', 'development')

require 'pry' if %w[development test].include?(app_env)

require_relative 'p1_tool/version'
require_relative 'p1_tool/errors'
require_relative 'p1_tool/adapters/audit_log'
require_relative 'p1_tool/adapters/file_system'
require_relative 'p1_tool/core/configuration_schema'
require_relative 'p1_tool/core/configuration_loader'
require_relative 'p1_tool/core/input_schema'
require_relative 'p1_tool/core/input_validator'
require_relative 'p1_tool/xml/builder_helpers'
require_relative 'p1_tool/xml/debug_support'
require_relative 'p1_tool/gateways/p1/client'
require_relative 'p1_tool/application/builders/encounter/constants'
require_relative 'p1_tool/application/contracts/register_encounter/payload_schema'
require_relative 'p1_tool/application/contracts/register_encounter/validation_helpers'
require_relative 'p1_tool/application/contracts/register_encounter/payload_validator'
require_relative 'p1_tool/application/builders/encounter/data_builder'
require_relative 'p1_tool/application/builders/encounter/xml_section_helpers'
require_relative 'p1_tool/application/builders/encounter/xml_builder'
require_relative 'p1_tool/application/integrations/p1/patient/find_or_create_stub'
require_relative 'p1_tool/application/integrations/p1/encounter/submit_stub'
require_relative 'p1_tool/application/operations/register_encounter'
require_relative 'p1_tool/application/dispatcher'
require_relative 'p1_tool/runtime/config_version'
require_relative 'p1_tool/runtime/execution_context'
require_relative 'p1_tool/runtime/task_processor'
require_relative 'p1_tool/runtime/workspace'
require_relative 'p1_tool/runtime/runtime_environment'
require_relative 'p1_tool/runtime/retry_policy'
require_relative 'p1_tool/runtime/sidekiq_config_loader'
require_relative 'p1_tool/runtime/processing_recovery'
require_relative 'p1_tool/runtime/continuous_task_processor'
require_relative 'p1_tool/runtime/continuous_runner'
require_relative 'p1_tool/jobs/current_job'
require_relative 'p1_tool/jobs/job_context_middleware'
require_relative 'p1_tool/jobs/inbox_scan_job'
require_relative 'p1_tool/jobs/process_task_job'
require_relative 'p1_tool/application/cli'

module P1Tool
  CLI = Application::CLI
end

# frozen_string_literal: true

ENV["APP_ENV"] = "test"

require "minitest/autorun"
require "minitest/spec"
require "minitest/pride" if ENV["MINITEST_PRIDE"] == "1" || $stdout.tty?
require "tmpdir"
require "stringio"
require "json"
require "fileutils"

require_relative "../lib/p1_tool"

module FixtureHelper
  def fixture_path(*parts)
    File.join(__dir__, "fixtures", *parts)
  end

  def fixture_text(*parts)
    File.read(fixture_path(*parts))
  end

  def fixture_json(*parts)
    JSON.parse(fixture_text(*parts))
  end

  def write_config_fixture(target_path, fixture_name:, replacements: {})
    content = fixture_text("config", fixture_name)
    replacements.each do |placeholder, value|
      content = content.gsub(placeholder, value)
    end

    FileUtils.mkdir_p(File.dirname(target_path))
    File.write(target_path, content)
    target_path
  end
end

class Minitest::Test
  include FixtureHelper
end

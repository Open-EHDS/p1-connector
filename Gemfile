# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.4.9'

gem 'dry-schema'
gem 'faraday'
gem 'jwt'
gem 'nokogiri'
gem 'sidekiq'
gem 'sidekiq-cron'

group :development, :test do
  gem 'pry'
  gem 'rake'
end

group :development do
  gem 'rubocop', require: false
  gem 'rubocop-minitest', require: false
end

group :test do
  gem 'minitest'
  gem 'simplecov', require: false
end

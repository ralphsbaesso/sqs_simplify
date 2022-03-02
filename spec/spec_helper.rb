# frozen_string_literal: true

require_relative 'simplecov_config'
require 'bundler/setup'
require 'sqs_simplify'

require 'examples/consumer_example'
require 'examples/scheduler_example'
require 'examples/job_example'

require 'helpers'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include Helpers

  config.before do
    SqsSimplify::FakerClient.purger!
  end

  config.before :suite do
    SqsSimplify.configure.faker = true
  end
end

Aws.config.update(stub_responses: true)

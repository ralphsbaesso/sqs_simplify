# frozen_string_literal: true

require 'aws-sdk-sqs'
require 'fileutils'
require 'json'
require 'ostruct'
require 'parallel'

require 'sqs_simplify/execution_hook'
require 'sqs_simplify/client'
require 'sqs_simplify/base'

require 'sqs_simplify/command'
require 'sqs_simplify/consumer'
require 'sqs_simplify/faker_client'

require 'sqs_simplify/message'
require 'sqs_simplify/scheduler'
require 'sqs_simplify/version'
require 'sqs_simplify/worker'

module SqsSimplify
  class Error < StandardError; end

  class << self
    def configure
      block_given? ? yield(setting) : setting
    end

    def setting
      @setting ||= OpenStruct.new(
        worker: SqsSimplify::Worker,
        root: Pathname.new(Dir.pwd)
      )
    end

    def logger
      @logger ||= Logger.new(setting.log_dir ||
                  "#{setting.root}/log/sqs_simplify.log")
    end
  end
end

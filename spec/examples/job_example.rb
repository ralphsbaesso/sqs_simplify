# frozen_string_literal: true

SqsSimplify.configure do |config|
  config.hooks.resolver_exception do |exception, args|
    JobExample.errors << [exception, args]
  end
end

class JobExample < SqsSimplify::Job
  set :queue_name, :my_job
  @@errors = []

  def method_one(value)
    "value: #{value}"
  end

  def method_two(value, arg:, arg1: 2)
    "values: #{value}, #{arg}, #{arg1}"
  end

  def method_three(value, arg = nil, *rest)
    "values: #{value}, #{arg}, #{rest}"
  end

  def errors
    @@errors
  end

  def self.errors
    @@errors
  end
end

class JobExample1 < SqsSimplify::Job
  namespace :inner do
  end
end

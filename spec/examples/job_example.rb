# frozen_string_literal: true

SqsSimplify.configure do |config|
  config.hooks.resolver_exception do |exception, args|
    JobExample.errors << [exception, args]
  end
end

class JobExample < SqsSimplify::Job
  set :queue_name, :my_job
  @@errors = []

  def perform(value)
    "value: #{value}"
  end

  def errors
    @@errors
  end

  def self.errors
    @@errors
  end
end

class JobExampleA < JobExample
  def perform(value, arg:, arg1: 2)
    "values: #{value}, #{arg}, #{arg1}"
  end
end

class JobExampleB < JobExample
  def perform(value, arg = nil, *rest)
    "values: #{value}, #{arg}, #{rest}"
  end
end

class JobExampleC < JobExample
  def perform(a:, b:, c: 'c', **rest, &_block)
    "values: #{a}, #{b}, #{c}, #{rest}"
  end
end

class JobExample1 < SqsSimplify::Job
end

class ChildrenJobExample < JobExample
end

class ChildrenJobExample2 < JobExample
  set :queue_name, :children_job2
end

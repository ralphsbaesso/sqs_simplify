# frozen_string_literal: true

require_relative '../../lib/sqs_simplify'

class SchedulerExample < SqsSimplify::Scheduler
  set :queue_name, 'my_queue'
  map_queue :input
end

class SchedulerExample1 < SqsSimplify::Scheduler
  map_queue :inner
end

class SchedulerExample2 < SqsSimplify::Scheduler
  set :queue_name, :queue_name
  map_queue :inner do |new_class|
    new_class.set :queue_name, :input
  end
end

class SchedulerExample3 < SqsSimplify::Scheduler
  set :queue_name, :queue_name
  map_queue :inner do |new_class|
    new_class.set :queue_name, :input
  end
end

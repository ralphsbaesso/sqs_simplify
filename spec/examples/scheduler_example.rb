# frozen_string_literal: true

require_relative '../../lib/sqs_simplify'

class SchedulerExample < SqsSimplify::Scheduler
  define_queue_name 'my_queue'
  map_queue :input, queue_name: 'input'
end

class SchedulerExample1 < SqsSimplify::Scheduler
  map_queue :inner
end

class SchedulerExample2 < SqsSimplify::Scheduler
  define_queue_name :queue_name
  map_queue :inner, queue_name: 'input'
end

class SchedulerExample3 < SqsSimplify::Scheduler
  define_queue_name :queue_name
  map_queue :inner, queue_name: 'input'
end

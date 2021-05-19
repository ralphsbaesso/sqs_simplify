# frozen_string_literal: true

require_relative '../../lib/sqs_simplify'

class SchedulerExample4 < SqsSimplify::Scheduler
  set :queue_name, 'queue1'
  map_queue :output do |new_class|
    new_class.set :queue_name, 'queue2'
  end
end

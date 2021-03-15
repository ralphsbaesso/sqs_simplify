# frozen_string_literal: true

require_relative '../../lib/sqs_simplify'

class SchedulerExample < SqsSimplify::Scheduler
  default_url 'https://aws.amazon/my_queue'

  map_queue :input, 'https://aws.amazon/input'
end

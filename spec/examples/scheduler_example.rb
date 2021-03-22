# frozen_string_literal: true

require_relative '../../lib/sqs_simplify'

class SchedulerExample < SqsSimplify::Scheduler
  default_url 'https://aws.amazon/my_queue'
  map_queue :input, queue_host: 'https://aws.amazon', queue_name: 'input'
end

class SchedulerExample1 < SqsSimplify::Scheduler
  default_url 'https://aws.amazon/queues'
  map_queue :inner, 'https://aws.amazon/queues1'
end

class SchedulerExample2 < SqsSimplify::Scheduler
  prefix = 'environment'
  host = 'https://aws.amazon'

  default_url queue_host: host, queue_name: :queue_name, queue_prefix: prefix
  map_queue :inner, queue_host: host, queue_name: 'input', queue_prefix: prefix
end

class SchedulerExample3 < SqsSimplify::Scheduler
  suffix = 'final'
  host = 'https://aws.amazon'

  default_url queue_host: host, queue_name: :queue_name, queue_suffix: suffix
  map_queue :inner, queue_host: host, queue_name: 'input', queue_suffix: suffix
end

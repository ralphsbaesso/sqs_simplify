# frozen_string_literal: true

require_relative '../../lib/sqs_simplify'

class SchedulerExample4 < SqsSimplify::Scheduler
  host = 'https://aws.amazon'
  default_url queue_host: host, queue_name: 'queue1'
  map_queue :output, queue_host: host, queue_name: 'queue2'
end
require_relative '../../lib/sqs_simplify'

class SchedulerExample < SqsSimplify::Scheduler
  set :queue_url, 'https://aws.amazon/my_queue'
end

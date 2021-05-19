# frozen_string_literal: true

class ConsumerExample < SqsSimplify::Consumer
  set :queue_name, 'my_queue'
end

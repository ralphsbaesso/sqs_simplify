# frozen_string_literal: true

class ConsumerExample < SqsSimplify::Consumer
  define_queue_name 'my_queue'
end

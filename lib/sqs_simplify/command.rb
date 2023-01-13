# frozen_string_literal: true

require 'optparse'

module SqsSimplify
  class Command
    attr_reader :env, :queues, :with_priority, :parallel_type, :worker_size

    def initialize(args = [])
      args = [] unless args.is_a? Array

      OptionParser.new do |opt|
        opt.on('-h', '--help', 'Show help') do
          puts opt
          exit 1
        end

        opt.on('-n', '--number_of_workers=workers', 'Number of unique workers to spawn') do |worker_count|
          @worker_size = build_work_count(worker_count)
        end

        opt.on('-e', '--environment=environment', 'Environment') { |env| @env = env }
        opt.on('--queues=queues', 'queues that will be consumed') { |queues| @queues = queues.split(',') }
        opt.on('--priority', 'with priority in the queues') { |priority| @with_priority = priority }
        opt.on('-f', '--fork', 'parallel in processes') { @parallel_type = :in_processes }
        opt.on('-t', '--thread', 'parallel in threads') { @parallel_type = :in_threads }
      end.parse! args
    end

    def daemonize(&block)
      @running_process = true
      block&.call(self)
      run!
    end

    private

    def build_work_count(number)
      worker_size = number.to_i
      worker_size.positive? && worker_size <= 11 ? worker_size : 1
    end

    def running_process?
      @running_process
    end

    def run!
      time = 0
      trap('SIGINT') { stop! }

      while running_process?
        if time.zero?
          amount_process = execute
          time = calculate_sleep(amount_process)
        else
          sleep 1
          time -= 1
        end
      end
    end

    def stop!
      puts ''
      puts 'this process will stop after consuming all messages!'
      @running_process = false
    end

    def execute
      worker = SqsSimplify::Worker.new(
        queues: queues,
        priority: with_priority,
        worker_size: worker_size,
        parallel_type: parallel_type
      ) do
        continues_the_process?
      end

      worker.perform
    end

    def calculate_sleep(amount)
      amount.to_i.zero? ? 10 : 0
    end

    def continues_the_process?
      running_process?
    end
  end
end

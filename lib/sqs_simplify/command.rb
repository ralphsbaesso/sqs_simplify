# frozen_string_literal: true

require 'daemons'
require 'optparse'

module SqsSimplify
  class Command
    def initialize(args = nil)
      @options = {
        pid_dir: "#{root}/tmp/pids",
        log_dir: "#{root}/log"
      }

      @worker_count = 1
      opts = OptionParser.new do |opt|
        opt.on('-h', '--help', 'Show help') do
          puts opt
          exit 1
        end

        opt.on('-n', '--number_of_workers=workers', 'Number of unique workers to spawn') do |worker_count|
          build_work_count(worker_count)
        end

        opt.on('-e', '--environment=environment', 'Environment') { |env| @options[:environment] = env }
        opt.on('--queues=queues', 'queues that will be consumed') { |queues| @queues = queues.split(',') }
        opt.on('--priority', 'with priority in the queues') { |priority| @priority = priority }

        opt.on('--pid-dir=DIR', 'Specifies an alternate directory in which to store the process ids.') do |dir|
          @options[:pid_dir] = dir
        end

        opt.on('--log-dir=DIR', 'Specifies an alternate directory in which to store the delayed_job log.') do |dir|
          @options[:log_dir] = dir
        end
      end

      @args = opts.parse!(args)
    end

    def daemonize
      self.running_process = true
      dir = @options[:pid_dir]
      FileUtils.mkdir_p(dir) unless File.exist?(dir)
      before_fork
      run_process
    end

    private

    attr_accessor :running_process

    def build_work_count(number)
      worker_count = number.to_i
      @worker_count = worker_count.positive? ? worker_count : 1
    end

    def run_process
      if @worker_count == 1
        run 'sqs_simplify'
      else
        @worker_count.times do |index|
          run "sqs_simplify.#{index}"
          sleep 1
        end
      end
    end

    def run(process_name)
      Daemons.run_proc(process_name, dir: @options[:pid_dir], dir_mode: :normal, ARGV: @args) do
        after_fork
        SqsSimplify.call_hook(:after_fork)
        time = 0

        while running_process
          if time.zero?
            amount_process = build_worker.perform
            time = calculate_sleep(amount_process)
          else
            sleep 1
            time -= 1
          end
        end
      end
    end

    def build_worker
      SqsSimplify::Worker.new(queues: @queues, priority: @priority) do
        continues_the_process?
      end
    end

    def calculate_sleep(amount)
      amount.zero? ? 10 : 0
    end

    def continues_the_process?
      trap('TERM') { self.running_process = false }
      trap('SIGINT') { self.running_process = false }
    end

    def root
      @root ||= SqsSimplify.settings.root
    end

    def after_fork
      @files_to_reopen.each do |file|
        file.reopen file.path, 'a+'
        file.sync = true
      rescue StandardError
        # Ignored
      end
    end

    def before_fork
      return if @files_to_reopen

      @files_to_reopen = []
      ObjectSpace.each_object(File) do |file|
        @files_to_reopen << file unless file.closed?
      end
    end
  end
end

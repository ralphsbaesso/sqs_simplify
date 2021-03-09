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
        opt.on('-h', '--help', 'Show this message') do
          puts opt
          exit 1
        end

        opt.on('-e', '--environment=environment', 'Environment') do |v|
          @options[:environment] = v
        end
        opt.on('-n', '--number_of_workers=workers', 'Number of unique workers to spawn') do |worker_count|
          @worker_count = begin
            worker_count.to_i
          rescue StandardError
            1
          end
        end
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
      dir = @options[:pid_dir]
      FileUtils.mkdir_p(dir) unless File.exist?(dir)
      run_process
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
        running = true
        trap('TERM') { running = false }
        trap('SIGINT') { running = false }

        while running
          amount_process = SqsSimplify::Worker.work
          sleep 10 if amount_process.zero?
        end
      end
    end

    def root
      @root ||= SqsSimplify.setting.root
    end
  end
end

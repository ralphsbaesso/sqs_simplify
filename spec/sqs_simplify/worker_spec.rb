# frozen_string_literal: true

RSpec.describe SqsSimplify::Worker do
  context 'instance methods' do
    context '#perform' do
      it 'must return an Integer' do
        worker = SqsSimplify::Worker.new
        response = worker.perform
        expect(response).to be_an(Integer)
      end

      it 'should throw an exception when there is no consumer' do
        allow_any_instance_of(SqsSimplify::Worker).to receive(:sqs_consumers).and_return([])

        worker = SqsSimplify::Worker.new
        expect { worker.perform }.to raise_error('No queue consumers were found in this project')
      end

      it 'should throw an exception when there is no consumer' do
        worker = SqsSimplify::Worker.new(queues: %w[fake_queue fake_queue1])
        expect { worker.perform }.to raise_error('Option queue invalid: [fake_queue, fake_queue1]')
      end

      context 'with queues arguments' do
        before { require_relative '../examples/job_with_consumer_spec' }

        it 'must match the queues' do
          queues = %w[job_slow job_medium job_fast]

          worker = SqsSimplify::Worker.new(queues: queues)
          response = worker.perform
          expect(response).to be_an(Integer)

          sqs_consumers = worker.send(:sqs_consumers)
          expect(sqs_consumers.map(&:queue_name)).to eq(queues)
        end

        it 'must return error to non existent queue' do
          queues = %w[job_slow job_medium job_fast job_not_exiting]

          worker = SqsSimplify::Worker.new(queues: queues)
          expect { worker.perform }.to raise_error(/Option queue invalid:/)
        end

        it 'must execution' do
          40.times { JobFast.new_job.perform_later }
          5.times { JobMedium.new_job.perform_later }
          2.times { JobSlow.new_job.perform_later }

          executions = []
          queues = %w[job_fast job_slow job_medium]

          worker = SqsSimplify::Worker.new(queues: queues, priority: true) do |_number, job|
            executions << job.queue_name if executions.last != job.queue_name
          end

          response = worker.perform

          expect(JobFast.count_messages).to eq(0)
          expect(JobMedium.count_messages).to eq(0)
          expect(JobSlow.count_messages).to eq(0)

          expect(response).to eq(47)
          expect(executions).to eq(%w[job_fast job_slow job_fast job_slow job_medium job_fast job_slow job_medium])
        end
      end
    end
  end
end

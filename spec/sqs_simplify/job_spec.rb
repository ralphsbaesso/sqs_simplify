# frozen_string_literal: true

RSpec.describe SqsSimplify::Job do
  context 'private constant' do
    it 'should raise an exception' do
      expect { SqsSimplify::Job.new }.to raise_error(/private method/)
    end
  end

  it 'job (<name_job>::Consumer>) must be included in the variable "jobs" of SqsSimplify' do
    expect(SqsSimplify.jobs.keys).to include(:job_example)
  end

  context 'class methods' do
    it 'must create dynamically methods' do
      expect(JobExample).to respond_to(:method_one)
    end

    context '.queue_name' do
      context 'sub modules must have the same queue name' do
        it '' do
          scheduler = JobExample.scheduler
          expect(JobExample.queue_name).to eq(scheduler.queue_name)

          consumer = JobExample.consumer
          expect(JobExample.queue_name).to eq(consumer.queue_name)
        end

        context 'with prefix' do
          before do
            JobExample.instance_variable_set :@queue_name, nil
            SqsSimplify.configure.queue_prefix = 'production'
          end
          after { SqsSimplify.configure.queue_prefix = nil }

          it do
            scheduler = JobExample.scheduler
            expect(JobExample.queue_name).to eq(scheduler.queue_name)
            expect(scheduler.queue_name).to eq('my_job')
            expect(scheduler.queue_full_name).to eq('production_my_job')

            consumer = JobExample.consumer
            expect(JobExample.queue_name).to eq(consumer.queue_name)
            expect(consumer.queue_name).to eq('my_job')
            expect(consumer.queue_full_name).to eq('production_my_job')
          end
        end
      end
    end

    context '.scheduler' do
      it do
        scheduler = JobExample.scheduler
        scheduler1 = JobExample1.scheduler
        expect(scheduler).to_not eq(scheduler1)
      end
    end

    context 'with FakerClient' do
      before do
        SqsSimplify.configure.faker = true
        clear_variables(JobExample, :@scheduler, :@consumer)
      end

      after { SqsSimplify.configure.faker = nil }

      context 'one cycle' do
        it do
          JobExample.method_one(:value1).now
          expect(JobExample.count_messages).to eq(1)

          consumer = JobExample.consumer
          consumer.send :consume_messages
          expect(JobExample.count_messages).to eq(0)

          expect(JobExample.errors.count).to eq(0)
        end
      end

      context '.schedule' do
        it 'must to schedule' do
          value = :test
          expect(JobExample.settings[:scheduler]).to be_truthy
          message_id = JobExample.method_one(value).now
          expect(message_id.to_i).to be > 0

          JobExample.set :scheduler, false
          expect(JobExample.settings[:scheduler]).to be_falsey
          expect(JobExample.method_one(value).now).to eq(:executed)
          expect(JobExample.method_two(value, arg: 123).later).to eq(:executed)
          expect(JobExample.method_three(value).later(1)).to eq(:executed)
        end
      end
    end
  end
end

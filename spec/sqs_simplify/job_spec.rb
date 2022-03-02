# frozen_string_literal: true

RSpec.describe SqsSimplify::Job do
  it 'job (<name_job>::Consumer>) must be included in the variable "jobs" of SqsSimplify' do
    expect(SqsSimplify.consumers.map(&:queue_name)).to include('my_job', 'job_example1')
  end

  context 'instance methods' do
    before do
      clear_variables(JobExample, :@scheduler, :@consumer, :@client)
    end

    context '#perform' do
      it 'must implement method "perform"' do
        job = SqsSimplify::Job.new_job
        expect { job.perform }.to raise_error(/NotImplemented/)
      end
    end

    context '#perform_later' do
      it 'must schedule methods' do
        job = JobExample.new_job
        uuid = job.perform_later 123
        expect(uuid).to be_a(String)

        job = JobExampleA.new_job
        uuid = job.perform_later 123, arg: 'X'
        expect(uuid).to be_a(String)

        job = JobExampleB.new_job
        uuid = job.perform_later 123, 1, 2, 3
        expect(uuid).to be_a(String)

        job = JobExampleC.new_job
        uuid = job.perform_later a: 1, b: 2, **{ e: 5, f: 6 }
        expect(uuid).to be_a(String)
      end
    end
  end

  context 'class methods' do
    context '.new' do
      it 'should raise an exception' do
        expect { SqsSimplify::Job.new }.to raise_error(/private method/)
      end
    end

    context '.queue_name' do
      context 'sub modules must have the same queue name' do
        it '' do
          scheduler = JobExample.scheduler
          expect(JobExample.queue_name).to eq(scheduler.queue_name)

          consumer = JobExample.consumer
          expect(JobExample.queue_name).to eq(consumer.queue_name)
        end

        it 'subclass must same queue_name the superclass by default' do
          expect(ChildrenJobExample.queue_name).to eq(JobExample.queue_name)
        end

        it 'subclass don\'t must same queue_name the super class when set queue_name' do
          expect(ChildrenJobExample2.queue_name).to_not eq(JobExample.queue_name)
          expect(ChildrenJobExample2.scheduler.queue_name).to_not eq(JobExample.queue_name)
          expect(ChildrenJobExample2.consumer.queue_name).to_not eq(JobExample.queue_name)
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

    context '.consumer.maximum_message_quantity' do
      it do
        [4, 7, 8, 9, 10].each do |amount|
          JobExample.set :maximum_message_quantity, amount
          expect(JobExample.consumer.send(:maximum_message_quantity)).to eq(amount)
        end
      end
    end

    context '.consumer_messages' do
      it do
        amount = [4, 7, 8, 9, 10].sample
        result = JobExample.consume_messages amount
        expect(result).to eq(0)
      end
    end

    context '.client' do
      it 'must share the same client in subclasses' do
        client = JobExample1.client
        expect(client).to be(JobExample1.scheduler.client)
        expect(client).to be(JobExample1.consumer.client)
      end
    end

    context 'with FakerClient' do
      before do
        clear_variables(JobExample, :@scheduler, :@consumer, :@client)
      end

      context 'one cycle' do
        it do
          JobExample.new_job.perform_later(:value1)
          expect(JobExample.count_messages).to eq(1)

          consumer = JobExample.consumer
          consumer.send :consume_messages
          expect(JobExample.count_messages).to eq(0)

          expect(JobExample.errors.count).to eq(0)
        end
      end

      context '.schedule' do
        after { SqsSimplify::Job.set :scheduler, true }

        it 'must to schedule' do
          value = :test
          expect(JobExample.new_job.perform(value)).to eq(:executed)

          expect(JobExample.settings[:scheduler]).to be_truthy
          message_id = JobExample.new_job.perform_later(value)
          expect(message_id).to_not eq(:executed)

          SqsSimplify::Job.set :scheduler, false
          expect(JobExample.new_job.perform(value)).to eq(:executed)
          expect(JobExampleA.new_job.perform_later(value, arg: 123)).to eq(:executed)
          expect(JobExampleB.new_job(after: 1).perform_later(value)).to eq(:executed)
        end
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe SqsSimplify::Scheduler do
  context 'private constant' do
    it 'should raise an exception' do
      expect { SqsSimplify::Scheduler.new('args') }.to raise_error(/private method/)
    end
  end

  context 'class methods' do
    context 'dynamic map' do
      it 'must respond to methods from Scheduler' do
        const_input = SchedulerExample.input
        expect(const_input).to respond_to(:send_message, :count_messages)

        expect { SchedulerExample::Input }.to raise_error(/private constant/)
      end
    end

    context '.send_message' do
      it 'send message and perform now' do
        allow(SchedulerExample).to receive(:queue_url).and_return('http://amozon.com')
        message = { a: 'a' }
        perform = SchedulerExample.send_message message

        expect(perform.class).to eq(SchedulerExample)
        message_id = perform.now
        expect(message_id).to be_truthy
      end
    end

    context '.queue_url' do
      it 'default' do
        expect(SchedulerExample1.queue_url).to_not be_nil
        expect(SchedulerExample1.queue_name).to eq('scheduler_example1')
        expect(SchedulerExample1.inner.queue_url).to_not be_nil
        expect(SchedulerExample1.inner.queue_name).to eq('scheduler_example1_inner')
      end

      context 'with prefix' do
        before { SqsSimplify.configure.queue_prefix = 'environment' }
        after { SqsSimplify.configure.queue_prefix = nil }

        it do
          expect(SchedulerExample2.queue_url).to_not be_nil
          expect(SchedulerExample2.queue_name).to eq('environment_queue_name')
          expect(SchedulerExample2.inner.queue_url).to_not be_nil
          expect(SchedulerExample2.inner.queue_name).to eq('environment_input')
        end
      end

      context 'with suffix' do
        before { SqsSimplify.configure.queue_suffix = 'final' }
        after { SqsSimplify.configure.queue_suffix = nil }

        it do
          expect(SchedulerExample3.queue_url).to_not be_nil
          expect(SchedulerExample3.queue_name).to eq('queue_name_final')
          expect(SchedulerExample3.inner.queue_url).to_not be_nil
          expect(SchedulerExample3.inner.queue_name).to eq('input_final')
        end
      end

      context 'prefix and suffix configured in SqsSiplify' do
        it do
          SqsSimplify.configure do |config|
            config.queue_prefix = 'aaa'
            config.queue_suffix = 'bbb'
          end

          require_relative '../examples/scheduler_other_example'

          expect(SchedulerExample4.queue_name).to include('aaa_', '_bbb')
          expect(SchedulerExample4.output.queue_name).to include('aaa_', '_bbb')
        end
      end
    end

    context '.call_hook' do
      before do
        SchedulerExample.resolver_exception do |_a, _b|
          @error_occurred = true
        end
      end

      it 'must mark error_occurred as true' do
        allow_any_instance_of(Aws::SQS::Client).to receive(:send_message).and_raise('One error')
        SchedulerExample.send_message({ payload: 123 }).now
        expect(@error_occurred).to be_truthy
      end
    end

    it 'send message and perform later' do
      allow(SchedulerExample).to receive(:queue_url).and_return('http://amozon.com')

      message = { a: 'a' }
      perform = SchedulerExample.send_message message

      expect(perform).to be_a(SchedulerExample)
      expect { perform.later }.to raise_error(ArgumentError)
      expect { perform.later('90') }.to raise_error('parameter must be a Integer')
      expect { perform.later(0) }.to raise_error('parameter must be between 1 to 960 seconds')
      expect { perform.later(961) }.to raise_error('parameter must be between 1 to 960 seconds')
      message_id = perform.later 960
      expect(message_id).to be_truthy
    end
  end
end

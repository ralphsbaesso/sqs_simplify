RSpec.describe SqsSimplify::Scheduler do
  context 'private constant' do
    it 'should raise an exception' do
      expect { SqsSimplify::Scheduler.new('args') }.to raise_error(/private method/)
    end
  end

  context 'class methods' do
    context '.send_message' do
      it 'send message and perform now' do
        message = { a: 'a' }
        perform = SchedulerExample.send_message message

        expect(perform.class).to eq(SchedulerExample)
        message_id = perform.now
        expect(message_id).to be_truthy
      end
    end

    it 'send message and perform later' do
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

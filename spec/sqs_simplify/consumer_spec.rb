# frozen_string_literal: true

RSpec.describe SqsSimplify::Consumer do
  context 'instance methods' do
    context '#consume_messages' do
      before do
        allow(ConsumerExample).to receive(:queue_url).and_return('https://aws.amazon.com')
        allow_any_instance_of(Aws::SQS::Types::ReceiveMessageResult)
          .to receive(:messages).and_return(build_messages)
      end

      it 'must return messages' do
        messages = ConsumerExample.send :fetch_messages
        expect(messages.count).to eq(5)

        consumer = ConsumerExample.send(:new, messages.first, 1)
        expect { consumer.perform }
          .to raise_error('Must implement this method')

        response = ConsumerExample.send(:delete_sqs_message, messages.first)
        expect(response).to eq(true)
      end
    end
  end

  context 'class methods' do
    context '.amount_processes' do
      it do
        expect(ConsumerExample.send(:amount_processes)).to be_nil

        ConsumerExample.set :amount_processes, 10
        expect(ConsumerExample.send(:amount_processes)).to eq(10)
      end
    end

    context '.consume_messages' do
      before do
        SqsSimplify.configure.faker = true
        ConsumerExample.instance_variable_set :@client, nil
      end
      after do
        SqsSimplify.configure.faker = nil
        ConsumerExample.instance_variable_set :@client, nil
      end

      it 'must return 0 without messages' do
        expect(ConsumerExample.send(:consume_messages)).to eq(0)
      end
    end
  end

  private

  def build_messages
    messages = []
    5.times do |index|
      messages << OpenStruct.new(
        body: { text: index }.to_json,
        receipt_handle: index.to_s,
        message_attributes: {}
      )
    end
    messages
  end
end

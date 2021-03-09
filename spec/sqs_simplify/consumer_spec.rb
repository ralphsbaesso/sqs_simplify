RSpec.describe SqsSimplify::Consumer do
  context 'instance methods' do
    context '.consume_messages' do
      before do
        allow_any_instance_of(Aws::SQS::Types::ReceiveMessageResult)
          .to receive(:messages).and_return(build_messages)
      end
      it 'must return messages' do
        messages = ConsumerExample.send :fetch_messages
        expect(messages.count).to eq(5)

        expect { ConsumerExample.consume_message(messages.first) }
          .to raise_error('Must implement this method')

        response = ConsumerExample.send :delete_message, messages.first
        expect(response).to eq(true)
      end
    end
  end

  it 'must identify consumer class' do
    expect(SqsSimplify.mapped_consumers[ConsumerExample.name]).to be_truthy
  end

  private

  def build_messages
    messages = []
    5.times do |index|
      messages << OpenStruct.new(
        body: "text #{index}",
        receipt_handle: index.to_s,
        message_attributes: {}
      )
    end
    messages
  end
end

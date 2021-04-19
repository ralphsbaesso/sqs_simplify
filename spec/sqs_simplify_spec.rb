# frozen_string_literal: true

RSpec.describe SqsSimplify do
  it 'has a version number' do
    expect(SqsSimplify::VERSION).not_to be nil
  end

  context 'class methods' do
    context '.logger' do
      let(:path) { './log/sqs_simplify.log' }
      after do
        begin
          File.delete(path)
        rescue StandardError
          # Ignored
        end
      end
      it 'create file' do
        string = 'Test 123'
        SqsSimplify.logger.info string
        string = File.open(path).read
        expect(string).to end_with(string)
      end
    end
  end
end

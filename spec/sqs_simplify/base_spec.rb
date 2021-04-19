# frozen_string_literal: true

RSpec.describe SqsSimplify::Base do

  context 'class methods' do
    context 'dump_message' do
      it 'must return String' do
        hash = { id: 123, payload: 'ABCDEF' }
        response = SqsSimplify::Base.dump_message(hash)
        expect(response).to be_a(String)
      end
    end
  end
end

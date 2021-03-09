RSpec.describe SqsSimplify::Worker do
  context 'class methods' do
    context '.hooks' do
      before do
        SqsSimplify::Worker.instance_variable_set :@hooks, nil
      end

      it 'setting hooks' do
        expect(SqsSimplify.setting.worker).to eq(SqsSimplify::Worker)

        SqsSimplify.configure do |config|
          config.worker.before(:all) { |args| "do some #{args}" }
          config.worker.before(:each) { |args| "do some #{args}" }
          config.worker.after(:all) { |args| "do some #{args}" }
          config.worker.after(:each) { |args| "do some #{args}" }
        end

        response = SqsSimplify::Worker.call_hook :before_all, :test
        expect(response).to eq('do some test')

        expect(SqsSimplify::Worker.hooks[:before_all]).to be_a(Proc)
        expect(SqsSimplify::Worker.hooks[:before_each]).to be_a(Proc)
        expect(SqsSimplify::Worker.hooks[:after_all]).to be_a(Proc)
        expect(SqsSimplify::Worker.hooks[:after_each]).to be_a(Proc)
      end
    end
  end
end

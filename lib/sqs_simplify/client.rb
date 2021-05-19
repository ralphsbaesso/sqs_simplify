# frozen_string_literal: true

module SqsSimplify
  module Client
    def client
      self.class.client
    end

    module ClassMethods
      def client
        return @client if @client

        args = {
          access_key_id: SqsSimplify.settings.access_key_id,
          secret_access_key: SqsSimplify.settings.secret_access_key,
          region: SqsSimplify.settings.region,
          stub_responses: SqsSimplify.settings.stub_responses
        }.select { |_k, v| v }

        @client =
          if SqsSimplify.settings.faker
            SqsSimplify::FakerClient.new
          else
            Aws::SQS::Client.new(args)
          end
      end
    end

    def self.included(base)
      base.extend ClassMethods
    end
  end
end

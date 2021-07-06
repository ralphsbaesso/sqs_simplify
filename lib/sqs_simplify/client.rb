# frozen_string_literal: true

module SqsSimplify
  module Client
    protected

    def client
      self.class.client
    end

    module ClassMethods
      def client
        @client ||= build_client
      end

      private

      def build_client
        args = {
          access_key_id: settings[:access_key_id] || SqsSimplify.settings.access_key_id,
          secret_access_key: settings[:secret_access_key] || SqsSimplify.settings.secret_access_key,
          region: settings[:region] || SqsSimplify.settings.region,
          stub_responses: SqsSimplify.settings.stub_responses
        }.select { |_k, v| v }

        SqsSimplify.settings.faker ? SqsSimplify::FakerClient.new : Aws::SQS::Client.new(args)
      end
    end

    def self.included(base)
      base.extend ClassMethods
    end
  end
end

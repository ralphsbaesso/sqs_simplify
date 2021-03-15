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
          access_key_id: SqsSimplify.setting.access_key_id,
          secret_access_key: SqsSimplify.setting.secret_access_key,
          region: SqsSimplify.setting.region
        }.select { |_k, v| v }

        @client =
          if SqsSimplify.setting.faker
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

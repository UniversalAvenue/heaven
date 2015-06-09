module Heaven
  module Jobs
    # A simple post to slack job
    class SimpleSlackPost
      @queue = :deployment_statuses

      def self.perform(message)
        Rails.logger.info "slack: #{message['text']}"

        slack_account.ping '',
          channel: "##{message['chat_room']}",
          attachments: [{
            text: message['text'],
            color: message['success'] ? 'good' : 'danger',
          }]
      end

      def self.slack_webhook_url
        ENV['SLACK_WEBHOOK_URL']
      end

      def self.slack_account
        @slack_account ||= Slack::Notifier.new(slack_webhook_url)
      end
    end
  end
end

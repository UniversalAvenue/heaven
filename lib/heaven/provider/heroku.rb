require_relative '../jobs/simple_slack_post'

module Heaven
  # Top-level module for providers.
  module Provider
    # A heroku API client.
    module HerokuApiClient
      def http_options
        {
          :url     => "https://api.heroku.com",
          :headers => {
            "Accept"        => "application/vnd.heroku+json; version=3",
            "Content-Type"  => "application/json",
            "Authorization" => Base64.encode64(":#{api_key}")
          }
        }
      end

      def http
        @http ||= Faraday.new(http_options) do |faraday|
          faraday.request :url_encoded
          faraday.adapter Faraday.default_adapter
          faraday.response :logger unless %w{staging production}.include?(Rails.env)
        end
      end

      def api_key
        user_api_key || ENV['HEROKU_API_KEY']
      end

      def user_api_key
        JSON.parse(ENV['HEROKU_API_KEYS'])[chat_user]
      rescue StandardError
        nil
      end
    end

    # A heroku build object.
    class HerokuBuild
      include HerokuApiClient

      attr_accessor :id, :info, :name
      def initialize(name, id)
        @id   = id
        @name = name
        @info = info!
      end

      def info!
        response = http.get do |req|
          req.url "/apps/#{name}/builds/#{id}"
        end
        Rails.logger.info "#{response.status} response for Heroku build info for #{id}"
        @info = JSON.parse(response.body)
      end

      def output
        response = http.get do |req|
          req.url "/apps/#{name}/builds/#{id}/result"
        end
        Rails.logger.info "#{response.status} response for Heroku build output for #{id}"
        @output = JSON.parse(response.body)
      end

      def lines
        @lines ||= output["lines"]
      end

      def stdout
        lines.map do |line|
          line["line"] if line["stream"] == "STDOUT"
        end.join
      end

      def stderr
        lines.map do |line|
          line["line"] if line["stream"] == "STDERR"
        end.join
      end

      def refresh!
        Rails.logger.info "Refreshing build #{id}"
        info!
      end

      def completed?
        success? || failed?
      end

      def success?
        info["status"] == "succeeded"
      end

      def failed?
        info["status"] == "failed"
      end
    end

    # The heroku provider.
    class HerokuHeavenProvider < DefaultProvider
      include HerokuApiClient

      attr_accessor :build
      def initialize(guid, payload)
        super
        @name = "heroku"
      end

      def app_name
        return nil unless custom_payload_config

        app_key = "heroku_#{environment}_name"
        if custom_payload_config.key?(app_key)
          custom_payload_config[app_key]
        else
          puts "Specify a There is no heroku specific app #{app_key} for the environment #{environment}"
          custom_payload_config["heroku_name"]  # default app name
        end
      end

      def archive_link
        @archive_link ||= api.archive_link(name_with_owner, :ref => sha)
      end

      def execute
        response = build_request
        return unless response.success?
        body   = JSON.parse(response.body)
        @build = HerokuBuild.new(app_name, body["id"])

        until build.completed?
          sleep 10
          build.refresh!
        end

        log_to_slack(
          text: "[Build app on heroku](https://dashboard.heroku.com/apps/#{app_name}/activity/builds/#{build.id}) - #{build.success? ? 'OK' : 'failed'}",
          success: build.success?,
          chat_room: custom_payload['notify']['room'])
        return unless build.success?

        post_build_tasks.each do |task|
          if task.split.first == 'run'
            execute_and_log ['heroku', 'run', '--exit-code', '--app', app_name, task.sub(/\Arun /, '')], {}, false
          else
            execute_and_log ['heroku', task, '--app', app_name], {}, false
          end
          log_to_slack(
            text: "Running #{task} on heroku - #{last_child.success? ? 'OK' : 'failed'}",
            success: last_child.success?,
            chat_room: custom_payload['notify']['room'])
        end
      end

      def notify
        update_output

        if build
          output.stderr = build.stderr + output.stderr
          output.stdout = build.stdout + output.stdout
        else
          output.stderr = "Unable to create a build"
        end

        output.update
        if build && build.success?
          status.success!
        else
          status.failure!
        end
      end

      private

      def build_request
        http.post do |req|
          req.url "/apps/#{app_name}/builds"
          body = {
            :source_blob => {
              :url     => archive_link,
              :version => sha
            }
          }
          req.body = JSON.dump(body)
        end
      end

      def post_build_tasks
        custom_payload_config['after_build'] || []
      end

      def log_to_slack(message)
        Resque.enqueue Heaven::Jobs::SimpleSlackPost, message
      end
    end
  end
end

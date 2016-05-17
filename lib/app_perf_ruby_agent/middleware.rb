module AppPerfRubyAgent
  class Middleware
    def initialize(app, collector, path_exclude_patterns)
      @app = app
      @collector = collector
      @path_exclude_patterns = path_exclude_patterns
    end

    def call(env)
      if exclude_path? env["PATH_INFO"]
        @app.call(env)
      else
        @collector.collect do
          begin
            response = notifications.instrument "request.rack", :path => env["PATH_INFO"], :method => env["REQUEST_METHOD"] do
              instrumenters.each(&:before)
              response = @app.call(env)
              instrumenters.each(&:after)
              response
            end
          rescue Exception => e
            handle_exception(env, e)
          end
          response
        end
      end
    end

    protected

    def handle_exception(env, exception)
      notifications.instrument "ruby.error", :path => env["PATH_INFO"], :method => env["REQUEST_METHOD"], :message => exception.message, :backtrace => exception.backtrace
      raise exception
    end

    def exclude_path?(path)
      @path_exclude_patterns.any? { |pattern| pattern =~ path }
    end

    def notifications
      ActiveSupport::Notifications
    end

    def instrumenters
      Rails.application.config.apm.instruments.select(&:active?)
    end
  end
end

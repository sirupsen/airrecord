require 'thread'

module Airrecord
  class FaradayRateLimiter < Faraday::Middleware
    class << self
      attr_accessor :requests
    end

    def initialize(app, requests_per_second: nil, sleeper: nil)
      super(app)
      @rps = requests_per_second
      @sleeper = sleeper || ->(seconds) { sleep(seconds) }
      @mutex = Mutex.new
      clear
    end

    def call(env)
      @mutex.synchronize do
        wait if too_many_requests_in_last_second?
        @app.call(env).on_complete do |_response_env|
          requests << Process.clock_gettime(Process::CLOCK_MONOTONIC)
          requests.shift if requests.size > @rps
        end
      end
    end

    def clear
      self.class.requests = []
    end

    private

    def requests
      self.class.requests
    end

    def too_many_requests_in_last_second?
      return false unless @rps
      return false unless requests.size >= @rps
      window_span < 1.0
    end

    def wait
      # Time to wait until making the next request to stay within limits.
      # [1.1, 1.2, 1.3, 1.4, 1.5] => 1 - 0.4 => 0.6
      wait_time = 1.0 - window_span
      @sleeper.call(wait_time)
    end

    # [1.1, 1.2, 1.3, 1.4, 1.5] => 1.5 - 1.1 => 0.4
    def window_span
      requests.last - requests.first
    end
  end
end

Faraday::Request.register_middleware(
  # Avoid polluting the global middleware namespace with a prefix.
  :airrecord_rate_limiter => Airrecord::FaradayRateLimiter
)

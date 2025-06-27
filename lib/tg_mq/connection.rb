require 'base64'
require 'telegram/bot'
require 'timeouter'
require 'monitor'

module TgMq
  class Connection
    attr_reader :logger

    # curl -X POST -H 'Content-Type: application/json' -d '{"chat_id": "-1002782239054", "text": "This is a test from curl", "disable_notification": true}' https://api.telegram.org/bot XX:YY/sendMessage

    # curl -X GET -H 'Content-Type: application/json' https://api.telegram.org/XX:YY/getUpdates

    RAW_MAX_SIZE = 3057

    class Buffer
      def initialize(chunk_size: RAW_MAX_SIZE, size: 10)
        @buffer = ''
        @chunk_size = chunk_size

        @ready = SizedQueue.new(size)
        @mx = Monitor.new
        @cbs = []
      end

      def push(data, &cb)
        chunks = []
        @mx.synchronize do
          @buffer += data
          @cbs << cb

          while @buffer.size >= @chunk_size
            chunks << @buffer.slice!(0...@chunk_size) # ... -ТРИ ТОЧКИ НЕ ВКЛЮЧИТЕЛЬНО!
            chunks.last.instance_variable_set('@_cbs', @cbs.slice!(0..-1))
          end
        end

        chunks.each do |chunk|
          @ready.push(chunk)
        end
      end

      def pop(timeout: 1)
        @mx.synchronize do
          return @buffer.empty? ? nil : @buffer.slice!(0..-1) if @ready.empty?
        end

        @ready.pop(timeout: timeout)
      end
    end

    def initialize(itoken:, otoken:, channel:, logger: TgMq.config.logger)
      @logger = TgMq.setup_logger(logger).tagged(self.class)

      @mx = Monitor.new

      @itoken = itoken
      @otoken = otoken
      @channel = channel

      @buffer = Buffer.new

      @output_bot = ::Telegram::Bot::Client.new(@otoken, timeout: 5)
      @output_shaper = OutputShaper.new(chunk_size: 4080)

      @input_bot = ::Telegram::Bot::Client.new(@itoken, timeout: 5)
      @input_shaper = InputShaper.new(logger: logger)

      # Telegram Bot api alows 30 rps, we use only 20
      @delay = 60.0 / 29.0
      $r = 0

      @threads = []
      @threads << start_sender(@output_shaper, @output_bot, @delay)
    end

    def enqueue_message(data, &cb)
      raise 'Unable to enqueue message: connection is stopped' if stopped?

      logger.debug("Enqueue message of #{data.size} bytes")
      @buffer.push(data, &cb)
      # @output_shaper.enqueue_data(data, &cb)
    end

    def stopped?
      @stopped
    end

    def stop(timeout = 2)
      return if @stopped

      @stopped = true
      @output_bot.stop
      @input_bot.stop
      @output_shaper.stop

      if wait_for_termination(timeout)
        true
      else
        @threads.each(&:kill)
        false
      end
    end

    def wait_for_termination(timeout = 0)
      Timeouter.run(timeout) do |t|
        return true if @threads.all? do |thread|
          thread.join(t.left)
        end
      end
    end

    def receive!
      raise 'Unable to receive message: connection is stopped' if stopped?

      subscribe do |line|
        return line
      end
    end

    def subscribe!(&block)
      raise 'Unable to subscribe: connection is stopped' if stopped?

      @input_bot.listen do |message|
        case message
        when Telegram::Bot::Types::Message
          text = (message&.new_chat_title || message&.text || message&.pinned_message&.text).to_s
          logger.debug "Receive raw: [#{text.first(15)}...] of #{text.size} bytes"

          if (data = @input_shaper.pushdata(text))
            decoded = Base64.strict_decode64(data)
            logger.debug "Receive payload: of #{decoded.size} bytes"
            block.call(decoded)
          end
        end
      end
    end

    def start_sender(output_shaper, bot, delay)
      next_send_at = Time.at(0)

      Thread.new(output_shaper, bot) do |c, b|
        until @stopped
          break if @stopped
          next(sleep 1) if Time.now < next_send_at

          chunk = @buffer.pop(timeout: 1)
          break if @stopped
          next(sleep 1) if chunk.nil?

          @output_shaper.enqueue_data(chunk) do |*args|
            (chunk.instance_variable_get('@_cbs') || []).each do |cb|
              cb.call(*args)
            end
          end

          frame = c.deq(timeout: 1)
          break if @stopped
          next(sleep 1) if frame.nil?

          logger.debug "Sending frame [#{frame.id}] of #{frame.data.size} bytes..."

          response = tgretry do
            b.api.sendMessage(chat_id: @channel, text: "```\n#{frame.data}\n```",
                              disable_notification: true,
                              protect_content: true, parse_mode: 'markdown')
          end

          raise 'Unable to send message' unless response&.message_id

          sleep 0.1
          pin_response = tgretry do
            b.api.pinChatMessage(chat_id: @channel, message_id: response.message_id, disable_notification: true)
          end

          begin
            frame.callback&.call(pin_response)
          rescue StandardError
            nil
          end

          next_send_at = Time.now + delay * 2
        end
      rescue StandardError => e
        logger.error e.inspect
        raise
      end
    end

    def tgretry
      yield
    rescue Telegram::Bot::Exceptions::ResponseError => e
      if e.error_code.to_i == 429
        logger.warn "Retry packet send in #{@delay} seconds..."
        sleep @delay
        retry
      end
    end
  end
end

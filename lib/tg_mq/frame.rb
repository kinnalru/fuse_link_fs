module TgMq
  class Frame
    BEGIN_MSG = 'tgw'
    BEGIN_RX = /^#{BEGIN_MSG}\[(?<seq>\d+):(?<msg_id>\d+):(?<num>\d+)\](?<msg>.*)/

    END_MSG = ':wgt'
    END_RX = /#{END_MSG}$/

    attr_reader :seq, :msg_id, :num, :chunk, :callback

    def initialize(seq, msg_id, num, chunk)
      @seq = seq
      @msg_id = msg_id
      @num = num
      @chunk = chunk
    end

    def self.parse(data)
      if (md = BEGIN_RX.match(data))
        new(md[:seq], md[:msg_id], md[:num].to_i, md[:msg])
      end
    end

    def id
      "#{message_id}:#{num}"
    end

    def message_id
      "#{seq}:#{msg_id}"
    end

    def data
      "#{BEGIN_MSG}[#{id}]#{chunk}"
    end

    def set_callback(&callback)
      @callback = callback
    end
  end
end

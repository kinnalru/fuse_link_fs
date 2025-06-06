module TgMq
  class Message
    include Enumerable

    def self.pack(seq, data, msg_id: Time.now.strftime('%L'), chunked: 4080)
      (data + Frame::END_MSG).scan(/.{1,#{chunked}}/).each_with_index.map do |chunk, idx|
        Frame.new(seq, msg_id, idx, chunk)
      end
    end

    def initialize(seq, chunks, msg_id: Time.now.strftime('%L'))
      @seq = seq
      @msg_id = msg_id
      @chunks = chunks
    end

    def each
      if block_given?
        idx = -1
        @chunks.each do |chunk|
          yield(Frame.new(@seq, @msg_id, idx += 1, chunk))
        end
      else
        to_enum(:each)
      end
    end
  end
end

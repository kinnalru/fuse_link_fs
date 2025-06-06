module TgMq
  class OutputShaper
    attr_reader :chunk_size

    def initialize(chunk_size: 110)
      @chunk_size = chunk_size
      @seq = 0
      @queue = SizedQueue.new(10)
    end

    def enqueue_data(data, &callback)
      frames = split_to_frames(next_seq!, data).to_a
      frames.last&.set_callback(&callback)
      frames.each do |frame|
        @queue << frame
      end
    end

    def deq(*args, **kwargs)
      @queue.deq(*args, **kwargs)
    end

    protected

    def next_seq!
      @seq += 1
    end

    def split_to_frames(seq, data, msg_id: Time.now.strftime('%L'))
      encoded = Base64.strict_encode64(data).strip

      (encoded + Frame::END_MSG).scan(/.{1,#{chunk_size}}/).each_with_index.map do |chunk, idx|
        Frame.new(seq, msg_id, idx, chunk)
      end
    end
  end
end

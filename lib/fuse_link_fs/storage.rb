require 'base64'
require 'cgi'
require 'net/http'

module FuseLinkFs
  class RetryCaptchaError < StandardError; end

  class Storage
    def initialize(providers, cache: nil)
      @providers = providers
      @cache = cache
    end

    def random_provider
      @providers.sample
    end

    def provider_for(link)
      @providers.find { |p| p.class.match?(link) }
    end

    def store(data)
      size = data.size
      encoded = Provider.enc(data)

      links = encoded.scan(/.{1,1900}/).each_with_index.map do |encoded_chunk, idx|
        store_to_link(encoded_chunk, type: 'chunk', size: size, idx: idx)
      end

      store_links_if_needed(links, size: size).tap do |result|
        puts "RESULT:#{result}"
      end
    end

    def analyze(link)
      list = { link => {} }

      puts "ANALYZE #{link}"

      data_uri = with_retry do
        provider_for(link).extract(link)
      end

      puts "  data_uri: #{data_uri}"


      #params = CGI.parse(URI(data_uri).query)
      params = URI(data_uri).query.split('&').each_with_object({}) do |s, o|
        k,v=s.split('=')
        o[k] = v
      end
      
      puts "    params: #{params}"
      type = if params.fetch('chunk', nil)
               'chunk'
             elsif params.fetch('links', nil)
               'links'
             else
               raise raise "invalid TYPE[1]:#{type}"
             end

      if type == 'chunk'
        list[link][:type] = 'chunk'
        list[link][:params] = params
      elsif type == 'links'
        list[link][:type] = 'links'
        list[link][:params] = params
        links = Provider.dec(params.fetch(type)).split('|')
        list[link][:links] = links.map { |lnk| analyze(lnk) }
      else
        raise "invalid TYPE:#{type}"
      end

      list
    end

    def extract(link)
      puts "EXTRACT:#{link}"
      return @cache[link] if @cache && @cache[link]

      provider = provider_for(link)

      data_uri = with_retry do
        provider.extract(link)
      end

      #params = CGI.parse(URI(data_uri).query)
      params = URI(data_uri).query.split('&').each_with_object({}) do |s, o|
        k,v=s.split('=')
        o[k] = v
      end

      type = if params.fetch('chunk', nil)
               'chunk'
             elsif params.fetch('links', nil)
               'links'
             else
               raise raise "invalid TYPE[1]:#{type}"
             end
      data = params.fetch(type)

      if type == 'chunk'
        data.tap do |d|
          @cache[link] = d if @cache
        end
      elsif type == 'links'
        links = Provider.dec(data).split('|')
        links.map do |lnk|
          extract(lnk)
        end.join.tap do |d|
          @cache[link] = d if @cache
        end
      else
        raise "invalid TYPE:#{type}"
      end
    end

    def store_links_if_needed(links, size:)
      return links.first if links.size <= 1

      next_links = links.each_slice(30).each_with_index.map do |group, idx|
        encoded = Provider.enc(group.join('|'))
        store_to_link(encoded, type: 'links', size: size, idx: idx)
      end

      store_links_if_needed(next_links, size: size)
    end

    def store_to_link(encoded_chunk, type:, size:, idx:)
      uri = Provider.mk_data_uri(encoded_chunk, type: type, size: size, idx: idx)
      puts "   store_to_link: #{uri} #{idx}"
      with_retry do
        random_provider.store(uri)
      end
    end

    def with_retry(count = 5, delay: 0.1, klass: nil)
      retries ||= 0
      yield(retries)
    rescue RetryCaptchaError => e
      sleep(delay * 10 + (retries**2) * delay)
      if (retries += 1) < count
        logger.warn "Retry after error: #{e.inspect}. #{e.backtrace}" if respond_to?(:logger)
        retry
      else
        raise if klass.nil?
        return nil if klass == :skip

        raise klass.new(e.message)
      end
    rescue StandardError => e
      sleep(delay + (retries**2) * delay)
      if (retries += 1) < count
        logger.warn "Retry after error: #{e.inspect}. #{e.backtrace}" if respond_to?(:logger)
        retry
      else
        raise if klass.nil?
        return nil if klass == :skip

        raise klass.new(e.message)
      end
    end
  end
end

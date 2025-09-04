require 'base64'
require 'cgi'
require 'net/http'
require 'socksify/http'

module FuseLinkFs
  class Provider
    def self.mk_data_uri(encoded_chunk, type:, size:, idx:)
      "http://data.local?#{type}=#{encoded_chunk}&sz=#{size}&i=#{idx}"
    end

    def self.enc(data)
      #Base64.strict_encode64(Base64.strict_encode64(data).strip).strip
      Base64.strict_encode64(data).strip
    end

    def self.dec(data)
      #Base64.decode64(Base64.decode64(data).strip).strip
      Base64.decode64(data).strip
    end

    def match?(*args, **kwargs)
      self.class.match?(*args, **kwargs)
    end

    def base
      URI(self.class.base.to_s)
    end

    def store_raw(raw)
      store(self.class.mk_data_uri(Base64.strict_encode64(raw).strip, type: 'chunk', size: raw.size))
    end

    def make_request(request)
      with_connection(request.uri) do |http|
        http.request request
      end
    end

    def extract(link)
      make_request(Net::HTTP::Get.new(URI(link.to_s))).fetch('Location')
    end

    def with_connection(uri, &block)
      Net::HTTP.start(uri.host, uri.port, read_timeout: 1, open_timeout: 1, use_ssl: uri.scheme == 'https', verify_mode: OpenSSL::SSL::VERIFY_NONE, &block)
    end

    LIST = []
  end

  class Provider::GooSu < Provider
    def self.base
      @base ||= URI('https://goo.su/frontend-api/convert').freeze
    end

    def self.match?(link)
      !!link.to_s['https://goo.su']
    end

    def store(data_uri)
      puts "stoging data_uri:#{data_uri}"
      req = Net::HTTP::Post.new(base)
      req['User-Agent'] =
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36'
      req['Accept'] = 'application/json'
      req.body = { url: data_uri.to_s, is_public: 1 }.to_json
      req.content_type = 'application/json'

      response = make_request(req)
      response.value
      puts response.body
      JSON(response.body).fetch('short_url')
    end
  end

  class Provider::ClckRu < Provider
    def self.base
      @base ||= URI('https://clck.ru/--').freeze
    end

    def self.match?(link)
      !!link.to_s['https://clck.ru']
    end

    def store(data_uri)
      uri = base
      uri.query = { url: data_uri }.to_query
      make_request(Net::HTTP::Get.new(uri)).body
    end

    def extract(link)
      location = super
      CGI.parse(URI(location).query).fetch('url').first
    rescue StandardError => e
      puts "Unable to extract from #{link}(#{location}):#{e}"
      raise
    end
  end

  class Provider::Kontentino < Provider
    def self.base
      @base ||= URI('https://kntn.ly/graphql').freeze
    end

    def self.match?(link)
      !!link.to_s['https://kntn.ly']
    end

    def store(data_uri)
      puts "stoging data_uri:#{data_uri}"
      req = Net::HTTP::Post.new(base)
      req['User-Agent'] =
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36'
      req['Accept'] = 'application/json'
      req.body = {
        "query": "\n        mutation createLinkMutation($input: NewLink!) {\n          createLink(input: $input) {\n            id\n            shortUrl\n          }\n        }\n      ",
        "variables": {
          "input": {
            "url": data_uri,
            "id": '',
            "domain": 'https://kntn.ly',
            "name": ''
          }
        },
        "operationName": 'createLinkMutation'
      }.to_json
      req.content_type = 'application/json'

      response = make_request(req)
      response.value
      (JSON(response.body).dig('data', 'createLink') || {}).fetch('shortUrl')
    end
  end

  #Provider::LIST << Provider::ClckRu << Provider::GooSu << Provider::Kontentino
  Provider::LIST << Provider::GooSu << Provider::Kontentino
end

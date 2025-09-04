RSpec.describe FuseLinkFs::Provider do
  subject { described_class }
  let(:data) { '1234567890987654321' }
  let(:encoded_data) { Base64.strict_encode64(data).strip }
  let(:data_size) { data.size }

  let(:data_url) { described_class.mk_data_uri(encoded_data, type: 'chunk', size: data_size) }

  it '#mk_data_uri' do
    url = described_class.mk_data_uri(encoded_data, type: 'chunk', size: data_size)
    expect(url).to include('http')
    expect(url).to include('chunk')
    expect(url).to include("s=#{data_size}")
  end

  describe FuseLinkFs::Provider::GooSu do
    subject(:provider) { FuseLinkFs::Provider::GooSu.new }

    it do
      link = provider.store(data_url)
      expect(provider.match?(link)).not_to eq false
      expect(link.to_s).to include('https://goo.su')

      expect(provider.extract(link)).to eq(data_url)
    end
  end

  describe FuseLinkFs::Provider::ClckRu do
    subject(:provider) { FuseLinkFs::Provider::ClckRu.new }

    it do
      link = provider.store(data_url)
      expect(provider.match?(link)).not_to eq false
      expect(link.to_s).to include('https://clck.ru')

      expect(provider.extract(link)).to eq(data_url)
    end
  end


end

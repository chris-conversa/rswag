require 'rswag/specs/request_factory'

module Rswag
  module Specs

    describe RequestFactory do
      subject { RequestFactory.new(config) }

      before do
        allow(config).to receive(:get_swagger_doc).and_return(swagger_doc)
      end
      let(:config) { double('config') } 
      let(:swagger_doc) { {} }
      let(:example) { double('example') }
      let(:metadata) do
        {
          path_item: { template: '/blogs' },
          operation: { verb: :get }
        }
      end

      describe '#build_request(metadata, example)' do
        let(:request) { subject.build_request(metadata, example) }

        it 'builds request hash for given example' do
          expect(request[:verb]).to eq(:get)
          expect(request[:path]).to eq('/blogs')
        end

        context "'path' parameters" do
          before do
            metadata[:path_item][:template] = '/blogs/{blog_id}/comments/{id}'
            metadata[:operation][:parameters] = [
              { name: 'blog_id', in: :path, type: :number },
              { name: 'id', in: :path, type: :number }
            ]
            allow(example).to receive(:blog_id).and_return(1)
            allow(example).to receive(:id).and_return(2)
          end

          it 'builds the path from example values' do
            expect(request[:path]).to eq('/blogs/1/comments/2')
          end
        end

        context "'query' parameters" do
          before do
            metadata[:operation][:parameters] = [
              { name: 'q1', in: :query, type: :string },
              { name: 'q2', in: :query, type: :string }
            ]
            allow(example).to receive(:q1).and_return('foo')
            allow(example).to receive(:q2).and_return('bar')
          end

          it "builds the query string from example values" do
            expect(request[:path]).to eq('/blogs?q1=foo&q2=bar')
          end
        end

        context "'query' parameters of type 'array'" do
          before do
            metadata[:operation][:parameters] = [
              { name: 'things', in: :query, type: :array, collectionFormat: collection_format }
            ]
            allow(example).to receive(:things).and_return([ 'foo', 'bar' ])
          end

          context 'collectionFormat = csv' do
            let(:collection_format) { :csv }
            it "formats as comma separated values" do
              expect(request[:path]).to eq('/blogs?things=foo,bar')
            end
          end

          context 'collectionFormat = ssv' do
            let(:collection_format) { :ssv }
            it "formats as space separated values" do
              expect(request[:path]).to eq('/blogs?things=foo bar')
            end
          end

          context 'collectionFormat = tsv' do
            let(:collection_format) { :tsv }
            it "formats as tab separated values" do
              expect(request[:path]).to eq('/blogs?things=foo\tbar')
            end
          end

          context 'collectionFormat = pipes' do
            let(:collection_format) { :pipes }
            it "formats as pipe separated values" do
              expect(request[:path]).to eq('/blogs?things=foo|bar')
            end
          end

          context 'collectionFormat = multi' do
            let(:collection_format) { :multi }
            it "formats as multiple parameter instances" do
              expect(request[:path]).to eq('/blogs?things=foo&things=bar')
            end
          end
        end

        context "'header' parameters" do
          before do
            metadata[:operation][:parameters] = [ { name: 'Api-Key', in: :header, type: :string } ]
            allow(example).to receive(:'Api-Key').and_return('foobar')
          end

          it 'adds names and example values to headers' do
            expect(request[:headers]).to eq({ 'Api-Key' => 'foobar' })
          end
        end

        context 'optional parameters not provided' do
          before do
            metadata[:operation][:parameters] = [
              { name: 'q1', in: :query, type: :string, required: false },
              { name: 'Api-Key', in: :header, type: :string, required: false }
            ]
          end

          it 'builds request hash without them' do
            expect(request[:path]).to eq('/blogs')
            expect(request[:headers]).to eq({})
          end
        end

        context 'optional parameter named include' do
          context 'not included' do
            before do
              metadata[:operation][:parameters] = [
                { name: 'include', in: :query, type: :string, required: false }
              ]
              allow(example).to receive(:include).and_return(RSpec::Matchers::BuiltIn::Include.new)
            end

            it 'builds request hash without them' do
              expect(request[:path]).to eq('/blogs')
            end
          end

          context 'included' do
            before do
              metadata[:operation][:parameters] = [
                { name: 'include', in: :query, type: :string, required: false }
              ]
              allow(example).to receive(:include).and_return('foo')
            end

            it 'builds request hash without them' do
              expect(request[:path]).to eq('/blogs?include=foo')
            end
          end
        end

        context "consumes content" do
          before do
            metadata[:operation][:consumes] = [ 'application/json', 'application/xml' ]
          end

          context "no 'Content-Type' provided" do
            it "sets 'CONTENT_TYPE' header to first in list" do
              expect(request[:headers]).to eq('CONTENT_TYPE' => 'application/json')
            end
          end

          context "explicit 'Content-Type' provided" do
            before do
              allow(example).to receive(:'Content-Type').and_return('application/xml')
            end

            it "sets 'CONTENT_TYPE' header to example value" do
              expect(request[:headers]).to eq('CONTENT_TYPE' => 'application/xml')
            end
          end

          context 'JSON payload' do
            before do
              metadata[:operation][:parameters] = [ { name: 'comment', in: :body, schema: { type: 'object' } } ]
              allow(example).to receive(:comment).and_return(text: 'Some comment')
            end

            it "serializes first 'body' parameter to JSON string" do
              expect(request[:payload]).to eq("{\"text\":\"Some comment\"}")
            end
          end

          context 'form payload' do
            before do
              metadata[:operation][:consumes] = [ 'multipart/form-data' ]
              metadata[:operation][:parameters] = [
                { name: 'f1', in: :formData, type: :string },
                { name: 'f2', in: :formData, type: :string }
              ]
              allow(example).to receive(:f1).and_return('foo blah')
              allow(example).to receive(:f2).and_return('bar blah')
            end

            it 'sets payload to hash of names and example values' do
              expect(request[:payload]).to eq(
                'f1' => 'foo blah',
                'f2' => 'bar blah'
              )
            end
          end
        end

        context 'produces content' do
          before do
            metadata[:operation][:produces] = [ 'application/json', 'application/xml' ]
          end

          context "no 'Accept' value provided" do
            it "sets 'HTTP_ACCEPT' header to first in list" do
              expect(request[:headers]).to eq('HTTP_ACCEPT' => 'application/json')
            end
          end

          context "explicit 'Accept' value provided" do
            before do
              allow(example).to receive(:'Accept').and_return('application/xml')
            end

            it "sets 'HTTP_ACCEPT' header to example value" do
              expect(request[:headers]).to eq('HTTP_ACCEPT' => 'application/xml')
            end
          end
        end

        context 'basic auth' do
          before do
            swagger_doc[:securityDefinitions] = { basic: { type: :basic } }
            metadata[:operation][:security] = [ basic: [] ]
            allow(example).to receive(:Authorization).and_return('Basic foobar')
          end

          it "sets 'HTTP_AUTHORIZATION' header to example value" do
            expect(request[:headers]).to eq('HTTP_AUTHORIZATION' => 'Basic foobar')
          end
        end

        context 'apiKey' do
          before do
            swagger_doc[:securityDefinitions] = { apiKey: { type: :apiKey, name: 'api_key', in: key_location } }
            metadata[:operation][:security] = [ apiKey: [] ]
            allow(example).to receive(:api_key).and_return('foobar')
          end

          context 'in query' do
            let(:key_location) { :query }

            it 'adds name and example value to the query string' do
              expect(request[:path]).to eq('/blogs?api_key=foobar')
            end
          end

          context 'in header' do
            let(:key_location) { :header }

            it 'adds name and example value to the headers' do
              expect(request[:headers]).to eq('api_key' => 'foobar')
            end
          end

          context 'in header with auth param already added' do
            let(:key_location) { :header }
            before do
              metadata[:operation][:parameters] = [
                { name: 'q1', in: :query, type: :string },
                { name: 'api_key', in: :header, type: :string }
              ]
              allow(example).to receive(:q1).and_return('foo')
              allow(example).to receive(:api_key).and_return('foobar')
            end

            it 'adds authorization parameter only once' do
              expect(request[:headers]).to eq('api_key' => 'foobar')
              expect(metadata[:operation][:parameters].size).to eq 2
            end
          end
        end

        context 'oauth2' do
          before do
            swagger_doc[:securityDefinitions] = { oauth2: { type: :oauth2, scopes: [ 'read:blogs' ] } }
            metadata[:operation][:security] = [ oauth2: [ 'read:blogs' ] ]
            allow(example).to receive(:Authorization).and_return('Bearer foobar')
          end

          it "sets 'HTTP_AUTHORIZATION' header to example value" do
            expect(request[:headers]).to eq('HTTP_AUTHORIZATION' => 'Bearer foobar')
          end
        end

        context 'paired security requirements' do
          before do
            swagger_doc[:securityDefinitions] = {
              basic: { type: :basic },
              api_key: { type: :apiKey, name: 'api_key', in: :query }
            }
            metadata[:operation][:security] = [ { basic: [], api_key: [] } ]
            allow(example).to receive(:Authorization).and_return('Basic foobar')
            allow(example).to receive(:api_key).and_return('foobar')
          end

          it "sets both params to example values" do
            expect(request[:headers]).to eq('HTTP_AUTHORIZATION' => 'Basic foobar')
            expect(request[:path]).to eq('/blogs?api_key=foobar')
          end
        end

        context "path-level parameters" do
          before do
            metadata[:operation][:parameters] = [ { name: 'q1', in: :query, type: :string } ]
            metadata[:path_item][:parameters] = [ { name: 'q2', in: :query, type: :string } ]
            allow(example).to receive(:q1).and_return('foo')
            allow(example).to receive(:q2).and_return('bar')
          end

          it "populates operation and path level parameters " do
            expect(request[:path]).to eq('/blogs?q1=foo&q2=bar')
          end
        end

        context 'referenced parameters' do
          before do
            swagger_doc[:parameters] = { q1: { name: 'q1', in: :query, type: :string } }
            metadata[:operation][:parameters] = [ { '$ref' => '#/parameters/q1' } ]
            allow(example).to receive(:q1).and_return('foo')
          end

          it 'uses the referenced metadata to build the request' do
            expect(request[:path]).to eq('/blogs?q1=foo')
          end
        end

        context 'global basePath' do
          before { swagger_doc[:basePath] = '/api' }

          it 'prepends to the path' do
            expect(request[:path]).to eq('/api/blogs')
          end
        end

        context "global consumes" do
          before { swagger_doc[:consumes] = [ 'application/xml' ] }

          it "defaults 'CONTENT_TYPE' to global value(s)" do
            expect(request[:headers]).to eq('CONTENT_TYPE' => 'application/xml')
          end
        end

        context "global security requirements" do
          before do
            swagger_doc[:securityDefinitions] = { apiKey: { type: :apiKey, name: 'api_key', in: :query } }
            swagger_doc[:security] = [ apiKey: [] ]
            allow(example).to receive(:api_key).and_return('foobar')
          end

          it 'applieds the scheme by default' do
            expect(request[:path]).to eq('/blogs?api_key=foobar')
          end
        end
      end
    end
  end
end

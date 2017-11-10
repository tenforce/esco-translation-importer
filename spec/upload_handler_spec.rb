require 'sparql/client'
require_relative '/usr/src/app/spec_helper.rb' # needed to use absolute path, should be solved in template
require 'linkeddata'

describe "upload" do
  before(:all) do
    @sample_file = File.dirname(__FILE__) + "/example.ttl"
    @graph = RDF::URI'http://test-graph/'
    @sparql_client = SPARQL::Client.new('http://database:8890/sparql')
    app.settings.sparql_client = @sparql_client
    app.settings.graph = @graph

  end 

  before(:each) do
    app.settings.sparql_client.clear(:graph, app.settings.graph)
  end

  context "basic (clearing)" do
    it "should return success" do   
      turtle = Rack::Test::UploadedFile.new(@sample_file, "text/turtle")
      post '/upload', file: turtle
      expect(last_response.status).to eq(200)
    end
    
    it "should remove existing data" do   
      triple = [ RDF::URI('http://wakaka.tenforce.com/subject'), RDF::URI('http://wakaka.tenforce.com/predicate'), RDF::URI('http://wakaka.tenforce.com/object')]
       data = RDF::Graph.new do |graph|
         graph << triple
       end
      @sparql_client.insert_data(data, graph: app.settings.graph)
      turtle = Rack::Test::UploadedFile.new(@sample_file, "text/turtle")
      post '/upload', file: turtle
      expect(@sparql_client.ask.from(app.settings.graph).whether(triple)).to be_false
    end

    it "should add all subjects to the configured graph" do
      turtle = Rack::Test::UploadedFile.new(@sample_file, "text/turtle")      
      post '/upload', file: turtle
      data = RDF::Graph.load(@sample_file, format:  :ttl).statements.map(&:to_hash)
      expect(@sparql_client.ask.from(app.settings.graph).whether(data)).to be_true
    end

    it "should generate uuids for every subject that does not have one" do
      turtle = Rack::Test::UploadedFile.new(@sample_file, "text/turtle")      
      post '/upload', file: turtle
      pattern = [RDF::URI('http://data.europa.eu/esco/label/00712a85-7610-4af2-ac47-6e5fafd0f4b8'), MU_CORE.uuid, :uuid]
      expect(@sparql_client.ask.from(app.settings.graph).whether(pattern)).to be_true
    end

    it "should reuse exisiting uuids from the graph" do
      pattern = [ RDF::URI('http://data.europa.eu/esco/label/00712a85-7610-4af2-ac47-6e5fafd0f4b8'), MU_CORE.uuid, '00712a85-7610-4af2-ac47-6e5fafd0f4b8' ]
       data = RDF::Graph.new do |graph|
         graph << pattern
       end
      app.settings.sparql_client.insert_data(data, graph: app.settings.graph)
      turtle = Rack::Test::UploadedFile.new(@sample_file, "text/turtle")      
      post '/upload', file: turtle
      expect(@sparql_client.ask.from(app.settings.graph).whether(pattern)).to be_true
    end 
  end

  context "incremental upload" do
    it "should keep resources not part of the uploaded file" do
      statement = [ RDF::URI('http://foo.bar/sub'), RDF::URI('http://foo.bar/baz'),  RDF::URI('http://foo.bar/bar') ]
      data = RDF::Graph.new do |graph|
        graph << statement
      end    
      app.settings.sparql_client.insert_data(data, graph: app.settings.graph)
      turtle = Rack::Test::UploadedFile.new(@sample_file, "text/turtle")      
      post '/upload', file: turtle, incremental: true
      expect(@sparql_client.ask.from(app.settings.graph).whether(statement)).to be_true
    end

    it "should replace resources completely if they are part of the file" do
      statement = [ RDF::URI('http://data.europa.eu/esco/label/001f80d9-2024-4774-a335-bf78449a47e0'), RDF::URI('http://foo.bar/baz'),  RDF::URI('http://foo.bar/bar') ]
      data = RDF::Graph.new do |graph|
        graph << statement
      end    
      app.settings.sparql_client.insert_data(data, graph: app.settings.graph)
      turtle = Rack::Test::UploadedFile.new(@sample_file, "text/turtle")      
      post '/upload', file: turtle, incremental: true
      expect(@sparql_client.ask.from(app.settings.graph).whether(statement)).to be_false
    end
  end 
end

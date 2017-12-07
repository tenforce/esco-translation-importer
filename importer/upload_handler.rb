require 'securerandom'

class SesameClient
  def initialize(select_endpoint, update_endpoint)
    @select_client = Sparql::Client.new(select_endpoint)
    @update_client = Sparql::Client.new(update_endpoint)
  end
end
class Importer::UploadHandler
  attr_accessor :base_uri, :incremental

  def initialize(client:, file:, default_graph:, logger:,graph_store:)
    @client = client
    @file_path = file
    @default_graph = default_graph
    @temp_graph = RDF::URI.new("import:#{SecureRandom.uuid}")
    @slice_size = 2000
    @logger = logger
    @graph_store = graph_store
  end


  def base_uri
    @base_uri ||="http://semte.ch/import/"
  end

  def file_stream
    @file_path.read
  end

  def import_file
    existing_map = uuid_map(@default_graph)
    if incremental
      create_graph(@temp_graph)
      ensure_uuids(@temp_graph, existing_map)
      replace_resources
      remove_graph(@temp_graph)
    else
      remove_graph(@default_graph)
      create_graph(@default_graph)
      ensure_uuids(@default_graph, existing_map)
    end
  end

  def remove_graph(graph)
    @client.clear(:graph, graph)
  end

  def endpoint
    @client.url
  end
  
  def headers
    @client.headers
  end

  def create_graph(graph)
    uri = URI("#{@graph_store}?graph=#{graph}")
    @logger.info "creating graph #{graph}"
    request = Net::HTTP::Post.new(uri, headers)
    request.body = file_stream
    request.content_type = "text/turtle"
    res = Net::HTTP.start(uri.hostname, uri.port) {|http|
      http.request(request)
    }
    res.body
  end
  
  def ensure_uuids(graph, existing_resources_uuids)
    id_map = uuid_map(graph, existing_resources_uuids) 
    statements = id_map.map { |url, uuid| [url, MU_CORE.uuid, uuid] }
    pointer = 0
    until pointer > statements.size 
      @client.insert_data statements.slice(pointer, @slice_size), graph: graph
      pointer = pointer + @slice_size
    end
  end
  
  def distinct_resources
    count_query= %Q(
      SELECT COUNT(?s) as ?count
      WHERE {
        GRAPH <#{@temp_graph.to_s}> {
          ?s [] []
        }
      }
    )
    results = @client.query(count_query)
    if results.empty?
      0
    else
      results.first["count"]
    end
  end

  def replace_resources
    replace_query = %Q(
    DELETE {
      GRAPH <#{@default_graph.to_s}> {
         ?s ?p ?o
      }
      GRAPH <#{@temp_graph.to_s}> {
        ?s ?q ?v
      }
    }
    INSERT {
      GRAPH <#{@default_graph.to_s}> {
         ?s ?q ?v
      }
    }
    WHERE {
      {
      SELECT ?s
        WHERE {
          GRAPH <#{@temp_graph.to_s}> {
            ?s [] []
          }
        } LIMIT #{@slice_size}
      }
      GRAPH <#{@temp_graph.to_s}> {
        ?s ?q ?v
      }
      OPTIONAL {
        GRAPH <#{@default_graph.to_s}> {
          ?s ?p ?o
        }
      }
    }
    )
    while distinct_resources > 0
      @client.update(replace_query)
      @logger.info "#{distinct_resources} to go"
    end
  end

  def uuid_map(graph, existing_map = {})
    map = {}
    uuid_query = %Q(
      SELECT ?uri ?uuid
      WHERE {
        GRAPH <#{graph.to_s}> {
            ?uri [] []
          OPTIONAL {
            ?uri <#{MU_CORE.uuid.to_s}> ?uuid
          }        
        }
      } 
    )
    results = @client.query(uuid_query)
    results.each_solution do |r| 
      uri = r.uri
      if existing_map.has_key? uri
        map[uri] = existing_map[uri]
      else
        if r.bound? "uuid"
         uuid = r.uuid
        else
         uuid = SecureRandom.uuid
        end
        map[uri] = uuid
      end
    end
    map
  end
end

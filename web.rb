require_relative 'importer.rb'

configure do
  if ENV['MU_GRAPH_STORE_ENDPOINT']
    set :graph_store_endpoint, ENV['MU_GRAPH_STORE_ENDPOINT']
  else
    set :graph_store_endpoint, ENV['MU_APPLICATION_GRAPH']
  end
end
## returns the current version, useful for monitoring?
get "/ping" do
  { version: Importer::VERSION }.to_json
end

post "/upload" do
  begin 
    importer = Importer::UploadHandler.new(
      client: settings.sparql_client, 
      file: params['file'][:tempfile],
      default_graph: settings.graph,
      logger: settings.log,
      graph_store: settings.graph_store_endpoint
    )
    if params[:incremental]
      importer.incremental = true
    end
    importer.import_file
  rescue Exception => e
    message = "error during upload #{e.message}"
    log.error message
    log.error e.backtrace
    error message, 500
 end
 status 200
 {
   meta: { status: "success"}
 }  
end

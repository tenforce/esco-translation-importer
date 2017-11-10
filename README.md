# Importer

Import is a microservice for the mu.semte.ch platform. As the name implies it provides API's to import datasets on the platform. It provides some general services (such as providing mu:uuid's for each resource) and some esco specific ones. The esco specific ones are separate api calls.

## Testing

```
docker run -d -e SPARQL_UPDATE=true --name test-db tenforce/virtuoso:1.0.0-virtuoso7.2.4 
docker run --rm --link test-db:database --volume `pwd`:/app -e MU_GRAPH_STORE_ENDPOINT=http://database:8890/sparql-graph-crud -e RACK_ENV=test semtech/mu-ruby-template:2.0.0-ruby2.3
```

## Installation
```
docker run -d -e SPARQL_UPDATE=true --name test-db tenforce/virtuoso:1.0.0-virtuoso7.2.4 
docker build -t importer . 
docker run -d --link test-db:database -e MU_GRAPH_STORE_ENDPOINT=http://database:8890/sparql-graph-crud importer
```
 **Note:** setting a graph store endpoint is not required, if not provided, it will default to the configured MU_SPARQL_ENDPOINT. For virtuoso use the example above.

## Importing a dataset
First of you should know that this service assumes only the most recent data is relevant for the platform. This means that when you replace existing resources no backup is kept of the old data. Secondly when a resource is present as a subject in the dataset the service assumes you provide the entire description for the resource.  So if you provide `<subject1> <predicate> <object>` all existing triples in the platform with `<subject1>` as subject will be dropped.



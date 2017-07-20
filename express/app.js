const express = require('express')
const app = express()

const elasticsearch = require('elasticsearch')
const es_client = elasticsearch.Client({
  host: process.env.ELASTICSEARCH_HOST + ':9200'
})
const es_index = 'ecs_index'
const es_type = 'ecs_type'
const express_port = 3000

// ensure es index exists
es_client.indices.create({
  index: es_index
}, function(err, resp, status) {
  // ensure es document exists
  es_client.index({
    index: es_index,
    type: es_type,
    id: 1,
    body: {
      foo: 'bar'
    }
  }, function(err, resp, status) {
    if (err) console.log('ERROR:', err)
  })
})

app.get('/', function (req, res) {
  es_client.search({
    index: es_index,
    type: es_type,
    body: {
      query: {
        match_all: {}
      }
    }
  }).then(function(response){
    res.send(response.hits.hits)
  }, function(error) {
    res.status(error.statusCode).send(error.message)
  })
})

app.listen(express_port, function () {
  console.log('App starting on port: ', express_port)
})

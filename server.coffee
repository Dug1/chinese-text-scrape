http = require 'http'
Promise = require 'bluebird'
fs = Promise.promisifyAll(require 'fs')
yaml = require 'js-yaml'
url = require 'url'
querystring = require 'querystring'

#server.coffee
#
#Basic framework for creating a web server, with routing and default 
#static file resolution.
#Also supports basic templating through render.
#See the files in templates/ for examples.

#Lookup table for routes
lookup = {}

#Default static foler
static_folder = "static/"

#Default 404 handler
not_found = (args, query) ->
  Promise.resolve({
      headers: {'Content-Type': 'text/html'},
      statusCode: 404,
      body: "<html><head><title>Page Not Found</title></head><h1> 404 Page Not Found </h1></html>"
  })

#Default css manager
css_manager = (args, query) ->
  fs.readFileAsync(static_folder + args)
  .then (body) ->
    return {
      headers: {'Content-Type': 'text/css'},
      statusCode: 200,
      body: body
    }

#Finds the function coressponding to a path
find = (path, method) ->
  console.log "#{method} : #{path}"
  for regex, func of lookup[method]
    r = new RegExp(regex)
    match = path.match(r)
    if match?
      return [func, match[1..(match.length - 1)]]
  return [not_found, []]
   
module.exports = 
  #Adds a route to the lookup
  route: (spec, func) ->
    if typeof spec == 'string'
      spec =
        method: "GET"
        regex: spec
    
    unless lookup[spec.method]?
      lookup[spec.method] = {}

    lookup[spec.method][spec.regex] = func

  #Serves the given path as html
  html: (path) ->
    fs.readFileAsync(path)
    .then (body) ->
      return {
        headers: {
          'Content-Type': 'text/html'
        },
        body: body
        statusCode: 200
      }
    .catch (e) ->
      return not_found(null, null)
  
  #Serves raw string as html
  html_str: (str) ->
    Promise.resolve({
      headers: {
        'Content-Type': 'text/html'
      },
      body: str
      statusCode: 200
    })

  #Serves data as yaml
  yml: (data) ->
    return_body =
      headers:
        'Content-Type': 'text/plain; charset=utf-8'
      statusCode: 200

    if typeof data == 'string'
      fs.readFileAsync(path)
      .then (body) ->
        return_body.body = body
        return return_body
      .catch (e) ->
        return not_found(null, null)
    else
      return_body.body = yaml.safeDump(data)
      Promise.resolve(return_body)

  #Renders with a template
  render: (template, args) ->
    Promise.resolve({
      headers: {
        'Content-Type': 'text/html'
      },
      body:require("./templates/#{template}.coffee")(args)
      statusCode: 200
    })

  #Starts the httpserver at the given port
  start: (port) ->
    http.createServer (req, res) ->
      url_obj = url.parse(req.url)
      path = url_obj.pathname
      query = querystring.parse(url_obj.query)
      [func, matches] = find(path, req.method)
      func(matches, query)
      .then (response) ->
        console.log "DONE"
        res.writeHead(response.statusCode, response.headers)
        res.end(response.body)
    .listen (port)
    console.log "Listening at 127.0.0.1:#{port}"

module.exports.route("^/static/(.*\.css)$", css_manager)

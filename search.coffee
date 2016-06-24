http = require 'http'
Promise = require 'bluebird'
fs = Promise.promisifyAll(require 'fs')
yaml = require 'js-yaml'
url = require 'url'
querystring = require 'querystring'

PORT = 3000

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
   
#Adds a route to the lookup
route = (spec, func) ->
  if typeof spec == 'string'
    spec =
      method: "GET"
      regex: spec
  
  unless lookup[spec.method]?
    lookup[spec.method] = {}

  lookup[spec.method][spec.regex] = func

#Serves the given path as html
html = (path) ->
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

html_str = (str) ->
  Promise.resolve({
    headers: {
      'Content-Type': 'text/html'
    },
    body: str
    statusCode: 200
  })

#Serves data as yaml
yml = (data) ->
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
render = (template, args) ->
  Promise.resolve({
    headers: {
      'Content-Type': 'text/html'
    },
    body:require("./templates/#{template}.coffee")(args)
    statusCode: 200
  })

route("^/static/(.*\.css)$", css_manager)

########################################### Framework End ########################################### 

search_file = (file, term) ->
  fs.readFileAsync(file)
  .then (text) ->
    console.log "Started analyzing #{file} for #{term}"
    histogram = {}
    latest_date = null
    date_index = 0
    index = 0
    passages = yaml.safeLoad(text).passages
    for passage, i in passages
      if passage.dates.length > 0
        latest_date = passage.dates[0]
        date_index = 0
      
      #Find instances of the term
      while (index = passage.text.indexOf(term, index)) > 0
        #move the latest date foward if multiple dates appear in a passage
        while latest_date and latest_date.index < index and date_index <= passage.dates.length
          date_index += 1
          latest_date = passage.dates[date_index]
        
        if latest_date
          unless histogram[latest_date.year]?
            histogram[latest_date.year] = 0
          histogram[latest_date.year] += 1
        index += 1

    console.log "Finished analyzing #{file} for #{term}"
    return histogram

#Searches all files for a term in a database and returns a histogram of the closest upstream instance
search_all = (term, database) ->
  promises = db[database].map((file) -> search_file(file + ".json", term))
  Promise.all(promises)
  .then (histograms) ->
    master = {}
    for histogram in histograms
      for date, count of histogram
        unless master[date]?
          master[date] = 0
        master[date] += count
    return master

############################## New handlers #############################

process_file_generic = (term, document) ->
  last_indicator = null
  notable_passages = []
  found_hit = false
  for passage in document.passages
    hits = []
    while (index = passage.text.indexOf(term, index)) > 0
      found_hit = true
      hits.push(index)
      index += 1

    dates = []
    indicator_index = -1
    for number in passage.numbers
      for indicator in passage.indicators
        if indicator.index > number.index
          indicator_index -= 1
          break
        indicator_index += 1
      
      indicator = if indicator_index == -1 then last_indicator else passage.indicators[indicator_index]
      if indicator?
        dates.push({index: number.index, date: indicator.date + number.number - 1, length:("#{number.number}".length + 1)})
      else
        dates.push({index: number.index, length:("#{number.number}".length + 1)})

      if passage.indicators.length > 0
        last_indicator = passage.indicators[passage.indicators.length - 1]

    if hits.length > 0 or passage.indicators.length > 0 or dates.length > 0
      notable_passages.push({text:passage.text, hits:hits, indicators: passage.indicators, dates: dates})

  if found_hit
    return notable_passages
  else
    return []

search_generic = (term, database) ->
  console.log "Searching #{database}"
  files = directory.directory[database]
  promises = files.map (file) ->
    link = "#"
    fs.readFileAsync(file)
    .then (body) ->
      data = JSON.parse(body)
      return {file: file, link:link, results: process_file_generic(term, data)}

  Promise.all(promises)
  .then (results) ->
    return results.filter (result) -> result.results.length > 0

search = (args, query) ->
  if query.database == "all"
    Promise.mapSeries(Object.keys(directory.directory), ((dir) -> search_generic(query.term, dir)))
    .then (results) -> 
      all = {}
      for key, i in Object.keys(directory.directory)
        all[key] = results[i]

      render("result", {term:query.term, results:all})
  else
    search_generic(query.term, query.database)
    .then (result) ->
      results = {}
      results[query.database] = result
      render("result", {term:query.term, results:results})

main = (args, query) ->
  keys = Object.keys(directory.directory)
  keys.push("all")
  render("index", {db:keys})

route("^[/]?$", main)
route("^/search/?$", search)

#Open up the directory
directory = JSON.parse(fs.readFileSync("directory.json"))

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
.listen (PORT)
console.log "Listening at 127.0.0.1:#{PORT}"

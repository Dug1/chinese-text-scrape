http = require 'http'
Promise = require 'bluebird'
fs = Promise.promisifyAll(require 'fs')
yaml = require 'js-yaml'
url = require 'url'
querystring = require 'querystring'
term_template = require './templates/term_template.coffee'

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

route("^/static/(.*\.css)$", css_manager)
########################################### Framework End ########################################### 

find_files = (root) ->
  fs.statAsync(root)
  .then (stat) ->
    if stat.isDirectory()
      fs.readdirAsync(root)
      .then (files) ->
        Promise.all(files.map((file) -> find_files("#{root}/#{file}")))
      .then (children) ->
        return children.reduce ((x, y) -> x.concat(y)), []
    else Promise.resolve([root])
  .then (files) ->
    return files
  .catch (e) ->
    console.log e
    return []

main = (args, query)->
  html("index.html")


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

search_no_years = (term, database) ->
  root = index.roots[database]
  find_files(root)
  .then (files) ->
    promises = files.map (file) ->
      console.log "Searching #{file}"
      link = "#"
      fs.readFileAsync(file)
      .then (body) ->
        data = yaml.safeLoad(body)
        link = data.link
        results = []
        for passage in data.passages
          result =
            text:passage.text
            hits: []
          while (index = passage.text.indexOf(term, index)) > 0
            result.hits.push(index)
            index += 1
          
          if result.hits.length > 0
            results.push result  
        return results
      .then (results) ->
        return {file: file, link:link, results: results}
    Promise.all(promises)
    .then (results) ->
      return results.filter (result) -> result.results.length > 0

search_no_years_all = (term) ->
  mapping = {}
  sources = ["舊唐書", "新唐書", "舊五代史", "新五代史", "宋史", "遼史", "金史", "元史", "明史", "清史稿"]
  Promise.mapSeries(sources,((source) -> search_no_years(term, source)))
  .then (results) ->
    for result, i in results
      mapping[sources[i]] = result
    return mapping

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

search = (args, query)->
  string = query.term
  db = query.database
  no_years = query.no_years
  if db == "all"
    search_no_years_all(string)
    .then (data) ->
      html_str(term_template({term:string, results:data}))
  else
    (if no_years == "true" then search_no_years else search_all)(string, db)
    .then (data) ->
      html_str(term_template({term:string, results:{"#{db}": data}}))
      
route("^[/]?$", main)
route("^/search/?$", search)

index = yaml.safeLoad(fs.readFileSync("index.json"))
# Find all files that actually have dates, seperated by database
db = {}
for name, dates of index.data
  files = {}
  for date in dates
    files[date.path] = true
  db[name] = Object.keys(files)

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

request = require('request-promise')
Promise = require('bluebird')
cheerio = require('cheerio')
fs = Promise.promisifyAll(require('fs'))
url = require('url')
path = require('path')
urlencode = require('urlencode')
processor = require('./processor.coffee')
yaml = require('js-yaml')

#scraper.coffee
#
#Used to generate data/. See the bottom of the file for example usage
#This file uses date.yml for metadata on databases.
#Also generates a directory.json file for easy indexing

MAX_FILE_SIZE = 60
UNICODE_SIZE = 2
FILENAME_SIZE = Math.floor(MAX_FILE_SIZE / UNICODE_SIZE) - 5

handle_section = (root_url, root, section, links, database) ->
  section_path = "#{root}#{section}" 
  fs.statAsync(section_path)
  .then (stat) ->
    console.log("#{section_path} already exists")
  .catch (err) ->
    console.log("Creating #{section_path}")
    fs.mkdirAsync(section_path)
  .then () -> 
    promises = links.map (link) ->
      url_to_use = url.resolve(root_url, link.ref)
      file_name = link.name[0...FILENAME_SIZE]
      path_name = root + section + path.sep + file_name
      request(url_to_use)
      .then (body) ->
        passages = processor.split(body)
        passage_dates = []
        dates_by_passage = processor.parse_dates(passages, database)
        for value, i in dates_by_passage
          passages[i].numbers = value.numbers
          passages[i].indicators = value.indicators

        console.log "Writing #{path_name}..."
        fs.writeFileAsync(path_name + ".json", JSON.stringify({link: url_to_use, filename: link.name, passages:passages}), {flag: 'w'})
        .then ()->
          return "#{path_name}.json"
        .catch (err) -> console.log(err)
    Promise.all(promises)

#Copies the object onto disk, downloading required pages
save = (object, database) ->
  #Create top level directories
  root_path = "#{object.data}#{url.parse(urlencode.decode(object.root)).path}".split(path.sep)
  #Adds parts before the path the the path entry
  temp = [""]
  for part in root_path
    temp.push("#{temp[temp.length-1]}#{part}#{path.sep}")
  root_paths = temp[1..-1]
  root = root_paths[root_paths.length - 1]

  #Generate root directories
  Promise.mapSeries(root_paths, (part) ->
    fs.statAsync(part)
    .then (stat)->
      console.log("#{part} already exists")
    .catch (err)->
      console.log("Creating #{part}")
      fs.mkdirAsync(part))
  .then ()->
    #Handle each section by creating child directories
    promises = []
    for section, links of object.sections
      promises.push(handle_section(object.root, root, section, links, database))
    Promise.all(promises)
  .then (paths)->
    #Collect files paths
    congregate = paths.reduce (x, y) -> x.concat(y)
    fs.readFileAsync("directory.json").then (text) ->
      console.log "Found directory.json"
      index = JSON.parse(text)
      index.directory[database] = congregate
      console.log "Writing directory.json"
      fs.writeFileAsync("directory.json", JSON.stringify(index))
    .catch (e) ->
      console.log "No directory.json"
      index = 
        directory: {}
      index.directory[database] = congregate
      console.log "Writing directory.json"
      fs.writeFileAsync("directory.json",JSON.stringify(index))

#Master url is the page containg the scrapable links, database
#signfies the database to in date.yml to use and data_root tells
#where to store the scraped data.
scrape = (master_url, database, data_root) ->
  request(master_url)
  .then (body) ->
    $ = cheerio.load(body)
  
    #Find links in the content sections
    #Seperated by subsections for easier file creation
    parsed_object =
      data: data_root
      root: master_url
      sections:
        misc:[]

    content = $("#mw-content-text")
    
    used = {}
    content.find("h2").each (i, el) ->
      #Found header, check to make sure it denotes a section
      headline = $(el).find("span.mw-headline")
      if headline.length > 0
        links = []
        section_name = headline.text()
        next = $(el).next()
        block = if next.get(0).tagName == "ul" then $(next) else $(next).find("ul")
        
        #Remember used blocks
        block.each (j, e) ->
          used[$(e).html()] = true

        block.find("li").each (j, e) -> 
          item = $(e)
          name = item.text()
          ref = item.find("a").first()
          unless ref.prop("class") == "new"
            links.push {name:name, ref: ref.prop("href")}
        parsed_object.sections[section_name] = links

    #Add the rest of the lists to misc
    content.find("ul, ol").filter (i, el) ->
      return not (used[$(el).html()]? or $(el).parents("#toc").length > 0)
    .each (i, el) ->
      $(el).find("li").each (j, e) -> 
        item = $(e)
        name = item.text()
        ref = item.find("a").first()
        unless ref.prop("class") == "new"
          parsed_object.sections.misc.push {name:name, ref: ref.prop("href")}

    save(parsed_object, database).then ()->
      console.log "done"
  .catch (err)->
    console.error err

scrape("https://zh.wikisource.org/zh/%E8%B3%87%E6%B2%BB%E9%80%9A%E9%91%91", "資治通鑑", "data")
.then () ->
  scrape("https://zh.wikisource.org/zh/%E7%BA%8C%E8%B3%87%E6%B2%BB%E9%80%9A%E9%91%91","續資治通鑑", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E8%88%8A%E5%94%90%E6%9B%B8", "舊唐書", "data")
.then () ->
 scrape("https://zh.wikisource.org/wiki/%E6%96%B0%E5%94%90%E6%9B%B8", "新唐書", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E8%88%8A%E4%BA%94%E4%BB%A3%E5%8F%B2", "舊五代史", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E6%96%B0%E4%BA%94%E4%BB%A3%E5%8F%B2", "新五代史", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E5%AE%8B%E5%8F%B2", "宋史", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E9%81%BC%E5%8F%B2", "遼史", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E9%87%91%E5%8F%B2", "金史", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E5%85%83%E5%8F%B2", "元史", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E6%98%8E%E5%8F%B2", "明史", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E6%B8%85%E5%8F%B2%E7%A8%BF", "清史稿", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E5%8F%B2%E8%A8%98", "史記", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E6%BC%A2%E6%9B%B8", "漢書", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E5%BE%8C%E6%BC%A2%E6%9B%B8", "後漢書", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E4%B8%89%E5%9C%8B%E5%BF%97", "三國志", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E6%99%89%E6%9B%B8", "晉書", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E5%AE%8B%E6%9B%B8", "宋書", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E5%8D%97%E9%BD%8A%E6%9B%B8", "南齊書", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E6%A2%81%E6%9B%B8", "梁書", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E9%99%B3%E6%9B%B8", "陳書", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E9%AD%8F%E6%9B%B8", "魏書", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E5%8C%97%E9%BD%8A%E6%9B%B8", "北齊書", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E5%91%A8%E6%9B%B8", "周書", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E9%9A%8B%E6%9B%B8", "隋書", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E5%8D%97%E5%8F%B2", "南史", "data")
.then () ->
  scrape("https://zh.wikisource.org/wiki/%E5%8C%97%E5%8F%B2", "北史", "data")
.then () ->
  console.log "done"

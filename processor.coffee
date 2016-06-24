cheerio = require 'cheerio'
yaml = require 'js-yaml'
fs = require 'fs'

###
processor.coffee

Used to process html files and will do the following
 - Divide the content into passage
   - Make each paragraph it's own passage
   - For now we also make each header into 
 - Locate dates and converts them into a gregorian date
 - Tags the passages each date appears in, along with a character index
 -Saves the file in the appropriate directory
###

#Parses integer from a Chinese numeral string
#Ignores the "base words and constructs the numeral from there
#Special treatment numbers 10-20
parse_number = (string) ->
  number_regexp = new RegExp(number_regexp_str, "g")
  base = if string[0] == "十" then 1 else 0
  matches = string.match(number_regexp)
  if matches
    for s in matches
      base *= 10
      base += digits[s]
  else
      base *= 10
  return base

#This is then general parser
#Finds keywords and keeps track of them, trying to match years to a year,
#using the closest key word it can find to indicate a year 
parse_general = (passages, metadata)->
  year_indicators = metadata.indicators
  last_indicator = null
  date_passages = []
  for passage in passages
    #If we have no indicators, push on empty arrays instead
    if Object.keys(year_indicators).length > 0
      #First we find indicators in the passage
      indicators = []
      indicator_regexp = new RegExp("(#{Object.keys(year_indicators).join("|")})", "g")
      while (results = indicator_regexp.exec(passage.text))?
        indicators.push({index: results.index, term:results[0], date:year_indicators[results[0]]})

      #Then we find the possible dates
      dates = []
      date_regexp = new RegExp(date_regexp_str, "g")
      while (result = date_regexp.exec(passage.text))?
        number = parse_number(result[0])
        dates.push({number: number, index: result.index})

      date_passages.push({indicators: indicators, numbers:dates})
    else
      date_passages.push({indicators: [], numbers:[]})
  
  return date_passages

parse_one = (passages, metadata) ->
  passage_dates = {}
  year_indicators = metadata.indicators
  year_range = metadata.range

  for passage in passages
    dates = []
    date_regexp = new RegExp("(#{Object.keys(year_indicators).join("|")})?" + date_regexp_str, "g")
    while (results = date_regexp.exec(passage.text))?
      [match, indicator, digits, year] = results
      new_date =
        year: -1
        index: results.index

      #Accept and indicator and and some numerical value or just a string of numbers only
      if indicator?
        new_date.year = year_indicators[indicator] + parse_number(digits) - 1
      else if (new RegExp("^" + number_regexp_str + "+$")).exec(digits)?
        new_date.year = parse_number(digits)
      else
        continue    

      #Ignore dates outside the given range
      if new_date.year in [year_range[0]..year_range[1]]
        dates.push new_date

    passages_dates.push(dates)

  return passage_dates
  
parse_two = (passage, metadata) ->
  year_indicators = metadata.indicators
  for passage in passages
    dates = []
    date_regexp = new RegExp("(#{Object.keys(year_indicators).join("|")})" + date_regexp_str, "g")
    while (results = date_regexp.exec(passage.text))?
      [match, indicator, digits, year] = results
      new_date =
        year: year_indicators[indicator] * parse_number(digits)
        index: results.index

      dates.push new_date
    passage_dates.push_dates

  return passage_dates 

parse_none = (passage) ->
  return []

#Lookup for parsers
lookup =
  續資治通鑑: parse_general
  資治通鑑: parse_general
  舊唐書: parse_general
  新唐書: parse_general
  舊五代史: parse_general
  新五代史: parse_general
  宋史: parse_general
  遼史: parse_general
  金史: parse_general
  元史: parse_general
  明史: parse_general
  清史稿: parse_general
  史記: parse_general
  漢書: parse_general
  後漢書: parse_general
  三國志: parse_general
  晉書: parse_general
  宋書: parse_general
  南齊書: parse_general
  梁書: parse_general
  陳書: parse_general
  魏書: parse_general
  北齊書: parse_general
  周書: parse_general
  隋書: parse_general
  南史: parse_general
  北史: parse_general

#Defers to appropriate database parser
exports.parse_dates = (passage, database) ->
  lookup[database](passage, date_data.metadata[database])

#Spilts the text into passages
exports.split = (text) ->
  $ = cheerio.load(text)
  data = $("div#mw-content-text").children("h2, p, pre, dl").map (i, elem) ->
    block = $(elem)
    passage =
      text: block.text()
      type: elem.tagName
    return passage
  return data.get()
  
date_data = yaml.safeLoad(fs.readFileSync('date.yml'))
digits = date_data.digits
years = date_data.years
base = date_data.base

#Construct the date finding regexp
date_regexp_str = "([#{Object.keys(digits).concat(Object.keys(base)).join("|")}]+)(#{years.join("|")})"
number_regexp_str = "(#{Object.keys(digits).join("|")})"
#passages = exports.split(fs.readFileSync("data/zh/續資治通鑑/misc/卷155"))
#for passage, i in passages
#  for date in exports.parse_dates(passage.text, '宋')
#    console.log passage.text
#    console.log date

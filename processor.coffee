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

parse_one = (passage) ->
  metadata = date_data.metadata.續資治通鑑
  year_indicators = metadata.indicators
  year_range = metadata.range
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

  return dates 
  
parse_two = (passage) ->
  metadata = date_data.metadata.資治通鑑
  year_indicators = metadata.indicators
  dates = []
  date_regexp = new RegExp("(#{Object.keys(year_indicators).join("|")})" + date_regexp_str, "g")
  while (results = date_regexp.exec(passage.text))?
    [match, indicator, digits, year] = results
    new_date =
      year: year_indicators[indicator] * parse_number(digits)
      index: results.index

    dates.push new_date

  return dates 

parse_none = (passage) ->
  return []

#Lookup for parsers
lookup =
  續資治通鑑: parse_one
  資治通鑑: parse_two
  舊唐書: parse_none
  新唐書: parse_none
  舊五代史: parse_none
  新五代史: parse_none
  宋史: parse_none
  遼史: parse_none
  金史: parse_none
  元史: parse_none
  明史: parse_none
  清史稿: parse_none
  史記: parse_none
  漢書: parse_none
  後漢書: parse_none
  三國志: parse_none
  晉書: parse_none
  宋書: parse_none
  南齊書: parse_none
  梁書: parse_none
  陳書: parse_none
  魏書: parse_none
  北齊書: parse_none
  周書: parse_none
  隋書: parse_none
  南史: parse_none
  北史: parse_none

#Defers to appropriate database parser
exports.parse_dates = (passage, database) ->
  lookup[database](passage)

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
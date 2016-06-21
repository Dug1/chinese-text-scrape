module.exports = (env) ->
  toc = []
  blocks = []
  for source, results of env.results
    formated_results = []
    toc_files = []
    for file, k in results
      file_results = []
      for passage in file.results
        text = passage.text
        for hit, i in passage.hits
          index = hit + i * 27
          text = text[0...index] + "<span class=\"match\">" + text[index...index+env.term.length] + "</span>" + text[index+env.term.length...text.length]

        file_results.push("<p>#{text}</p>")
      
      toc_files.push("<li><a href=\"##{source}-#{k}\">#{file.file}</a></li>")
      formated_results.push("""
          <div class="file" id="#{source}-#{k}">
            <a class="file_title" href="#{file.link}">#{file.file}</a>
            #{file_results.join("\n")}
          </div>
      """)

    toc.push("""
      <li><a href="##{source}">#{source}</a>
        <ul>
          #{toc_files.join("\n")}
        </ul>
      </li>
    """)

    blocks.push("""
      <div class="source-block" id="#{source}">
        <h2>#{source}</h2>
          #{formated_results.join("\n")}
      </div>
    """)

  return """
  <html>
      <head>
          <meta charset="UTF-8"/>
          <title> Result </title>
          <link rel="stylesheet type="text/css" href="static/results.css">
      </head>
      <body>
          <h2> Table of Contents </h2>
          <div id="toc">
            <ul>
            #{toc.join("\n")}
            </ul>
          </div>
          <div id="main">
            #{blocks.join("\n")}
          </div>
      </body>
  </html>
  """

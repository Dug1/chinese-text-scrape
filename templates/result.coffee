module.exports = (env) ->
  toc = []
  blocks = []
  for source, results of env.results
    formated_results = []
    toc_files = []
    for file, k in results
      file_results = []
      for passage in file.results
        all_terms = []
        for hit in passage.hits
          all_terms.push({type: "hit", index: hit})

        for date in passage.dates
          all_terms.push({type:"date", index:date.index, data:date})

        for indicator in passage.indicators
          all_terms.push({type:"indicator", index:indicator.index, data:indicator})

        all_terms.sort((a, b) -> a.index - b.index)
        base = 0
        text = passage.text
        for term in all_terms
          index = term.index + base
          if term.type == "hit"
            text = text[0...index] + "<span class=\"hit\">" + text[index...index+env.term.length] + "</span>" + text[index+env.term.length...text.length]
            base += 25
          else if term.type == "date"
            date = term.data
            no_date = ([0...date.length].map () -> "?").join("")
            text = text[0...index] + "<span data-date=\"#{date.date ? no_date}\" class=\"date\">#{text[index...index+date.length]}</span>" + text[index+date.length...text.length]
            base += 39 + (date.date ? no_date).length
          else
            indicator = term.data
            text = text[0...index] + "<span class=\"indicator\">" + text[index...index+indicator.term.length] + "</span>" + text[index+indicator.term.length...text.length]
            base += 31

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
          <script src="https://code.jquery.com/jquery-3.0.0.min.js" integrity="sha256-JmvOoLtYsmqlsWxa7mDSLMwa6dZ9rrIdtrrVYRnDRH0="crossorigin="anonymous"></script>
          <script>
            $(document).ready(function () {
              $(".date").hover(
                function() {
                  var $this = $(this);
                  var old_text = $this.text();
                  var date = $this.data("date");
                  $this.text(date + '');              
                  $this.data("date", old_text);
                },
                function() {
                  var $this = $(this);                                                                                                                                                  
                  var old_text = $this.text();
                  var date = $this.data("date");
                  $this.text(date + '');
                  $this.data("date", old_text);
                  });
              });
          </script>
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

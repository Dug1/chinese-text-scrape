module.exports = (env) ->
  return """
    <html>
        <head>
            <meta charset="UTF-8"/>
            <title> Document Search </title>
            <link rel="stylesheet" type="text/css" href="static/main.css">
        </head>
        <body>
            <div class="main">
              <form action="search" method="get">
                  <input type="hidden" name="no_years" value="true">
                  Term: <br>
                  <input type="text" name="term"><br>
                  Source:<br>
                  <select name="database">
                      #{env.db.map((name) -> "<option value=\"#{name}\">#{name}</option>").join("\n")}
                  </select>
                  <input type="submit">
              </form>
              </div>
        </body>
    </html>
  """

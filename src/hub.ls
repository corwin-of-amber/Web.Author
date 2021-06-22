#process = @_process

require! {
  jquery: $
  lodash: _
  './viewer/html-viewer': { HTMLDocument }
  './ide/index.ls': { IDE }
  './net/mysql': { MySQLProject }
  #'./net/p2p.ls':    {AuthorP2P}
}

global.console = window.console   # for debugging


CLIENT_OPTS = void
#CLIENT_OPTS = servers: hub: 'ws://localhost:3300'


$ ->
  ide = new IDE

  $('body').append ide.layout.el
  ide.start!

  wp-convert-shortcodes = ->
    it.replace(/\[/g, '<').replace(/\]/g, '>')  # @todo

  fs = require('fs')
  fs.readFileSync('data/floc2022/template-page.html', 'utf-8')
    siteContent = wp-convert-shortcodes fs.readFileSync('data/floc2022/calendar.wp', 'utf-8')
    ide.viewer.render new HTMLDocument(..replace('{{site__content}}', """
      <script src="/build/wp/preamble.js"></script>      
      #{siteContent}"""))


  if 0
    p2p = new AuthorP2P(CLIENT_OPTS)
      ide.project.attach ..
      do ->> p2p.project = await p2p.open-project 'd1'
        ide.project.open ..
        ..getPdf!on 'change' viewer~open
        ide.editor.on 'request-save' -> ..upstream?download-src! ; p2p.shout!
      window.addEventListener 'beforeunload' ..~close

  if 1
    db = new MySQLProject(JSON.parse fs.readFileSync('data/floc2022/connect-info.json', 'utf-8'))
    window <<< {db}

  window <<< {ide, ide.project, ide.viewer}

  window.addEventListener 'beforeunload' ->
    Date::com$cognitect$transit$equals = \
    Date::com$cognitect$transit$hashCode = null
    for own prop of window
      if typeof window[prop] == 'object' then window[prop] = null
    document.body.innerHTML = ""

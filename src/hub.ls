#process = @_process
if typeof Buffer == 'undefined'
  window.Buffer = require('buffer').Buffer

require! {
  jquery: $
  lodash: _
  memfs
  './infra/volume-factory': { VolumeFactory, FsVolumeScheme }
  './viewer/html-viewer': { HTMLDocument }
  './viewer/wordpress/render.ls': { WordPressTheme }
  './viewer/wordpress/project.ls': { WordPressProject }
  './ide/index.ls': { IDE }
  './net/mysql': { MySQLProject }
  #'./net/p2p.ls':    {AuthorP2P}
  './net/static': { OnDemandFsVolumeScheme }
  './typeset/wasi-pdflatex': { PDFLatexBuild: W }
}

global.console = window.console   # for debugging


CLIENT_OPTS = void
#CLIENT_OPTS = servers: hub: 'ws://localhost:3300'

VolumeFactory.instance.schemes.set 'file', new FsVolumeScheme
VolumeFactory.instance.schemes.set 'memfs', \
  mfs-scheme = new OnDemandFsVolumeScheme(new memfs.Volume)


$ ->>
  ide = new IDE

  if 1
    await mfs-scheme.populate!

  $('body').append ide.layout.el
  ide.start 'tex'

  if 0
    p2p = new AuthorP2P(CLIENT_OPTS)
      ide.project.attach ..
      do ->> p2p.project = await p2p.open-project 'd1'
        ide.project.open ..
        ..getPdf!on 'change' viewer~open
        ide.editor.on 'request-save' -> ..upstream?download-src! ; p2p.shout!
      window.addEventListener 'beforeunload' ..~close

  if 0
    fs = require('fs')
    wp = new WordPressProject('/Users/corwin/var/tmp/floc2022-author', {wp_posts: 'wp_xsm8ru_posts'},
                              JSON.parse(fs.readFileSync('data/floc2022/connect-info.json', 'utf-8')))
      ..theme = new WordPressTheme('data/floc2022/template-page.html')
      ..on 'rendered' ({content}) -> ide.viewer.render content

    wp.build('workshops.wp')

  window <<< {ide, ide.project, ide.viewer, wp, W}

  # this is for development: break some dangling references when reloading the page
  window.addEventListener 'beforeunload' ->
    Date::com$cognitect$transit$equals = \
    Date::com$cognitect$transit$hashCode = null
    for own prop of window
      if typeof window[prop] == 'object' then window[prop] = null
    document.body.innerHTML = ""

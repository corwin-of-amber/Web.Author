/* Kremlin is a bit incomplete at the moment */
if typeof window != 'undefined'
  window.Buffer = require('buffer').Buffer
  window.process = require('process')
  #window.process.nextTick = (f, ...args) -> f(...args) # risky!!


require! {
  fs
  jquery: $
  lodash: _
  memfs
  './infra/volume': { SubdirectoryVolume, WatchPolicy }
  './infra/volume-factory': { VolumeFactory, FsVolumeScheme }
  './viewer/html-viewer': { HTMLDocument }
  './viewer/wordpress/render.ls': { WordPressTheme }
  './viewer/wordpress/project.ls': { WordPressProject }
  './ide/index.ls': { IDE }
  './net/mysql': { MySQLProject }
  './net/static': { OnDemandFsVolumeScheme }
  './net/local': { LocalDBSync }
}

#global.console = window.console   # for debugging


CLIENT_OPTS = void
#CLIENT_OPTS = servers: hub: 'ws://localhost:3300'

if typeof nw !== 'undefined' then window.DEV = true

VolumeFactory.instance.schemes.set 'file', \
  new FsVolumeScheme(fs, WatchPolicy.Centralized)
VolumeFactory.instance.schemes.set 'memfs', mfs-scheme = \
  new OnDemandFsVolumeScheme(new memfs.Volume,
                             WatchPolicy.IndividualWithRec)

/** @ohno for now, these are baked-in, because volume operations must be synchronous */
ASSETS = 
  '/home/': '/data/toxin-manual.tar'
  '/': '/data/examples.tar'


$ ->>
  ide = new IDE
    $('body').append ..layout.el

  sp = new URLSearchParams(location.search)
  opts = {}

  if 1
    await mfs-scheme.populate ASSETS
    ldb = new LocalDBSync('memfsync');
    await ldb.attach(VolumeFactory.get({scheme: 'memfs', path: '/'}))
    window <<< {ldb}

  if (p2p-workspace = sp.get('p2p'))?
    require! './net/p2p.ls': { AuthorP2P }
    p2p = new AuthorP2P(CLIENT_OPTS)
      if p2p-workspace then ..join that
    opts.restore = '+'  # don't reopen last project; instead, p2p project is opened later
    window <<< {p2p}

  ide.start opts

  if 1
    ide.project.add-recent {scheme: 'memfs', path: '/home/toxin-manual'}, , 'end'
    aliases = {'tikz/gallery': 'tikz-gallery'}
    for example in <[overleaf/scientific-writing-exercise overleaf/bibtex overleaf/acm-sigplan
                     acmart-minimal tikz/gallery]>
      ide.project.add-recent {scheme: 'memfs', path: "/examples/#{example}"}, \
                             aliases[example], 'end'
    if ide.config.is-first-time!
      ide.project.open-recent sp.get('project') ? 'scientific-writing-exercise'
      ide.help!

  update-pdf = ->
    if it.pdf?
      ide.viewer.open it.pdf.toBlob!, ide.viewer.selected-page  # @todo go to page 1 if not the same project
      if it.pdf.synctex?
        ide.viewer.synctex-open it.pdf.synctex.content, {base-dir: '/home'}  # @oops

  ide.project.on 'build:intermediate' update-pdf
  ide.project.on 'build:finished' update-pdf

  if !window.DEV
    window.addEventListener 'beforeunload', ide~store

  if p2p
    ide.interim-message "connecting to P2P workspace... 📡"
    do ->> await p2p.list-projects!
      p2p.project = await p2p.open-project ..0
        ide.project.open ..
        ide.file-select loc: ..get-file('main.tex')

  if 0
    ide.select-preset 'html'
    wp = new WordPressProject('/Users/corwin/var/tmp/floc2022-author', {wp_posts: 'wp_xsm8ru_posts'},
                              JSON.parse(fs.readFileSync('data/floc2022/connect-info.json', 'utf-8')))
      ..theme = new WordPressTheme('data/floc2022/template-page.html')
      ..on 'rendered' ({content}) -> ide.viewer.open content

    wp.build('workshops.wp')
    window <<< {wp}

  window <<< {ide}

  # this is for development: break some dangling references when reloading the page
  if window.DEV
    window.addEventListener 'unload' ->
      Date::com$cognitect$transit$equals = \
      Date::com$cognitect$transit$hashCode = null
      for own prop of window
        if typeof window[prop] == 'object' then window[prop] = null
      document.body.innerHTML = ""

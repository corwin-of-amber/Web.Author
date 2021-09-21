node_require = global.require ? -> {}
fs = node_require 'fs'
require! { 
    events: { EventEmitter }
    jquery: $
    lodash: _
    'synctex-js': { parser: synctex-parser }
    'pdfjs-dist': pdfjsLib
    '../infra/volume': { Volume }
    '../infra/fs-watch.ls': { FileWatcher }
    '../infra/non-reentrant.ls': non-reentrant
    '../infra/ongoing.ls': { global-tasks }
    '../infra/ui-pan-zoom': { Zoom }
    '../ide/problems.ls': { safe }
}

require './viewer.css'

# yeah...
pdfjsLib.GlobalWorkerOptions.workerSrc = './pdf.worker.js'



class PDFViewerCore extends EventEmitter

  (@pdf, @containing-element ? $('body')) ->
    super!
    @pages = {}
    if @pdf?
      @pages[1] = @render-page(1)
    @selected-page = undefined
    @canvas = undefined

    @zoom = 1.5
    @resolution = 2

    @watcher = new FileWatcher
      ..on 'change' non-reentrant ~>>
        await global-tasks.wait! ; await @reload!

  destroy: ->
    @_ongoing?cancel!
    @watcher.clear!
    @containing-element.empty! # umm

  open: (locator, page ? 1) ->>
    if locator instanceof Blob
      locator = {volume: null, filename: URL.createObjectURL(locator)}

    @loc = locator
    uri = @_to-uri(@loc)

    await pdfjsLib.getDocument(uri).promise
      @pdf?.destroy!
      @pdf = ..
      ..uri = uri
      if @loc.volume
        @watcher.single @loc.filename, fs: @loc.volume
      else
        @watcher.clear!
    @selected-page = Math.min(page, @pdf.num-pages)
    @refresh!
    @

  _to-uri: (loc) ->
    loc = Volume.externSync(loc)
    if loc.volume == fs then "file://#{loc.filename}" else loc.filename

  reload: ->
    if @loc then @open that, @selected-page

  render-page: (page-num) ->
    canvas = $('<canvas>')
    @pdf.getPage(page-num).then (page) ~>
      viewport = page.getViewport({scale: 1})
      scale = @zoom * @resolution
      viewport = page.getViewport({scale})
      ctx = canvas.0.getContext('2d')
      canvas.0
        ..width = viewport.width ; ..height = viewport.height
        ..style.width = "#{viewport.width / @resolution}px"

      @_ongoing?cancel!
      @_ongoing = page.render do
        canvasContext: ctx
        viewport: viewport
      @_ongoing.promise.then ~>
        {page, canvas}

    .catch -> if !(it instanceof pdfjsLib.RenderingCancelledException ||
                   it.message == 'Transport destroyed') then throw it

  goto-page: (page-num) ->
    @selected-page = page-num
    @pages[page-num] ?= @render-page(page-num)
      ..then (page) ~>
        if !page? then return # cancelled
        if !@canvas
          @containing-element.append (@canvas = page.canvas)
        else
          @canvas.replaceWith (@canvas = page.canvas)
        @emit 'displayed' page

  flush: -> @pages = {}

  refresh: -> @flush! ; if @selected-page then @goto-page that


class Nav_MixIn
  nav-bind-ui: ->
    @containing-element .keydown keydown_eh = (ev) ~>
      switch ev.code
        case "ArrowRight", "PageDown" => @go-next-page!  ; ev.preventDefault!
        case "ArrowLeft", "PageUp"    => @go-prev-page!  ; ev.preventDefault!
        case "Home"                   => @go-first-page! ; ev.preventDefault!
        case "End"                    => @go-last-page!  ; ev.preventDefault!
    @on 'close' ~>
      @containing-element .off 'click', click_eh

  go-next-page: ->
    if @pdf? && @selected-page < @pdf.num-pages
      @goto-page ++@selected-page

  go-prev-page: ->
    if @pdf? && @selected-page > 1
      @goto-page --@selected-page

  go-first-page: ->
    if @pdf then @goto-page 1

  go-last-page: ->
    if @pdf then @goto-page @pdf.num-pages


class Zoom_MixIn
  zoom-bind-ui: ->
    @_zoom = new Zoom(@containing-element[0])
      ..zoom = @zoom
      ..setZoom = (z) ~>
        @_ongoing?cancel!
        @canvas.width @canvas.width! * z / @zoom
        @zoom = z
        @emit 'resizing' @canvas
        @_debounce-refresh!
    @_debounce-refresh = _.debounce @~zoom-refresh, 300

  zoom-refresh: ->
    # no use refreshing once it gets too small
    if @zoom >= 1 then @refresh!


class SyncTeX extends EventEmitter

  (@sync-data) ->
    @overlay = $('<svg xmlns="http://www.w3.org/2000/svg">')
      ..addClass('synctex-overlay')
      ..on 'mousemove mousedown' @~mouse-handler
    @highlight = $(document.createElementNS('http://www.w3.org/2000/svg', 'rect'))
      ..addClass 'highlight'
      @overlay.append ..

  cover: (canvas, scale) ->
    canvas.parent!append @overlay
    @overlay.attr viewBox: "0 0 #{canvas.0.width / scale} #{canvas.0.height / scale}"
    @snap canvas

  snap: (canvas) ->
    @overlay.0.style.width = canvas.0.style.width

  remove: ->
    @overlay.remove! ; @

  walk: (block) ->*
    yield block
    for let b in block.blocks
      yield from @walk(b)

  hit-test: (block, point) !->*
    w = @walk(block)
    while !(cur = w.next!).done
      b = @_block-touchup(cur.value)
      if @hit-test-shallow(b, point) then yield b

  hit-test-shallow: (block, point) ->
    d = 2
    (block.left - d) <= point.x <= (block.left + block.width + d) && \
    (block.bottom - block.height - d) <= point.y <= (block.bottom + d)

  hit-test-single: (block, point) ->
    ht = @hit-test(block, point)
    while !(cur = ht.next!).done
      if @_block-criteria(cur.value)
        b = cur.value
    b

  /**
   * Hack: crop oversized boxes, which are sometimes created by title macros
   * or included graphics.
   */
  _block-touchup: (block) ->
    if block.elements?length == 0 && block.parent.width == 0
      ^^block
        anc = @_block-ancestors(block)
        while !(cur = anc.next!).done && (c = cur.value)
          if c.width  then ..width  = Math.min(..width,  c.width)
          if c.height then ..height = Math.min(..height, c.height)
    else block

  _block-criteria: (block) ->
    # A block is selectable if it contains some text/math element(s)
    block.type == 'horizontal' && \
      ((block.elements.some (.type in ['x', '$'])) || block.blocks.length == 0)

  _block-ancestors: (block) ->*
    c = block.parent; while c
      yield c
      c = c.parent

  _block-location: (block, p) ->
    if p? && block.elements?length
      loc = _.minBy(block.elements.filter (.type == 'k'), 
                    (e) -> Math.abs(e.left - p.x))
    loc ?= block
    {loc.file, loc.line, loc.page, loc.fileNumber}

  _block-dump: (block, with-elements=true) ->  # for debugging
    b = block
    console.log "#{b.file.name}:#{b.line}  #{b.type}  #{Math.round(b.left)},#{Math.round(b.bottom)} #{Math.round(b.width)}×#{Math.round(b.height)} "
    lloc = ""
    for e in b.elements
      loc = "#{e.file.name}:#{e.line}"
      if loc == lloc then loc = " " * loc.length else lloc = loc
      console.log "     #{loc}  #{e.type}  #{Math.round(e.left)},#{Math.round(e.bottom)} #{Math.round(e.width)}×#{Math.round(e.height)} " e

  focus: (block) ->
    @selected-block = block
    @highlight.attr x: block.left, y: block.bottom - block.height, \
                    width: block.width, height: block.height
    @highlight.show!
  
  blur: ->
    @selected-block = void
    @highlight.hide!

  mouse-handler: (ev) ->
    if (page-num = @selected-page)?
      ctm = @overlay.0.getScreenCTM()  # assuming ctm.a, ctm.d are the scaling factors
      p = {x: ev.offsetX / ctm.a, y: ev.offsetY / ctm.d}
      if (ht = @hit-test-single(@sync-data.pages[page-num], p))?
        @focus ht
        if ev.type === 'mousedown'
          #console.log '-' * 60, p
          #for [...@hit-test(@sync-data.pages[page-num], p)] => @_block-dump ..
          @emit 'synctex-goto' @_block-location(ht, p), ht
      else
        @blur!

  @from-file = (filename, _fs) ->>
    txt = await SyncTeX.read-file filename, _fs
    new SyncTeX(synctex-parser.parseSyncTex(txt))
      ..filename = filename

  @from-buffer = (buf) ->>
    txt = await SyncTeX.read-buffer buf
    new SyncTeX(synctex-parser.parseSyncTex(txt))

  @from = ->
    if it.volume? then @from-file it.filename, it.volume
                  else @from-buffer it

  @read-file = (filename, _fs = fs) -> new Promise (resolve, reject) ->
    if filename.endsWith('.gz')
      # apply gunzip (use intermediate stream to save memory)
      zlib = node_require('zlib'); stream-buffers = node_require('stream-buffers')
      _fs.createReadStream(filename)  .on 'error' -> reject it
      .pipe(zlib.createGunzip())     .on 'error' -> reject it
      .pipe(new stream-buffers.WritableStreamBuffer)
      .on 'finish' -> resolve @getContentsAsString('utf-8')
    else
      resolve _fs.readFileSync(filename, 'utf-8')

  @read-buffer = (buf) -> new Promise (resolve, reject) ->
    td = new TextDecoder()
    zlib = require('zlib')
    if is-gzip(buf) then zlib.gunzip buf, (err, data) ->
      if err then reject err else resolve td.decode(data)
    else resolve td.decode(buf)


# https://github.com/kevva/is-gzip/blob/master/index.js
is-gzip = (buf) ->
  if (!buf || buf.length < 3) then false
  else
    buf[0] == 0x1F && buf[1] == 0x8B && buf[2] == 0x08;


class SyncTeX_MixIn

  synctex-open: (filename-or-buffer, opts) ->>
    @synctex-init!
    @synctex?.remove!
    @synctex = null

    base-dir = opts?base-dir ? filename-or-buffer.volume?root.dir

    adjust = (pos) ~> pos
      ..file.path = @_synctex-relative-path(..file.path, base-dir)

    @synctex = await SyncTeX.from filename-or-buffer, opts?base-dir
      @pages[@selected-page]?then @~_synctex-page
      ..on 'synctex-goto' (pos, ht) ~> @emit 'synctex-goto' adjust(pos), ht
      #@_synctex-watcher.single filename

  synctex-init: ->
    if !@_synctex-init
      @_synctex-init = true
      @on 'displayed' (page) ~>
        if @synctex?
          @synctex.blur!
          @_synctex-page page
      @on 'resizing' (canvas) ~>
        @synctex?.snap canvas
      @_synctex-watcher = new FileWatcher
      #  ..on 'change' @~synctex-reload  # @todo this races Viewer's reload

  synctex-reload: ->
    if @synctex?filename
      @synctex-open that
      @refresh!

  synctex-locate: (pdf-loc) ->
    if !pdf-loc.volume? then return
    for suffix in ['.synctex.gz', '.synctex']
      try
        fn = pdf-loc.filename.replace(/(\.pdf|)$/, suffix)
        if pdf-loc.volume.statSync(fn).isFile!
          return {pdf-loc.volume, filename: fn}
      catch

  _synctex-page: (page) ->
    if @synctex?
      @synctex.cover page.canvas, @zoom * @resolution
      @synctex.selected-page = @selected-page

  _synctex-relative-path: (filename, base-dir) ->
    if base-dir && filename.startsWith(base-dir)
      filename.slice(base-dir.length)
    else filename



class PDFViewer extends PDFViewerCore

  open: (pdf, page) ->
    super pdf, page .then ~>
      synctex = @synctex-locate(@loc)
      if synctex? then @synctex-open synctex
      @ui-init! || @refresh!

  destroy: -> super! ; @synctex?remove!

  ui-init: ->
    if !@_ui-init
      @nav-bind-ui!
      @zoom-bind-ui!
      @_ui-init = true      
      
  state:~
    -> {@loc, @selected-page}
    (v) ->
      safe ~>> v.loc && @open v.loc, v.selected-page


PDFViewer:: <<<< Nav_MixIn:: <<<< Zoom_MixIn:: <<<< SyncTeX_MixIn::



export PDFViewer

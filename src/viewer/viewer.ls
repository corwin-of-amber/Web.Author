node_require = global.require ? -> {}
fs = node_require 'fs'
require! { 
    events: {EventEmitter}
    lodash: _
    '../infra/fs-watch.ls': {FileWatcher}
    'synctex-js': {parser: synctex-parser}
}



class ViewerCore extends EventEmitter

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
      ..on 'change' @~reload

  open: (uri) ->>
    if uri instanceof Blob
      uri = URL.createObjectURL(uri)
    else if uri.startsWith('/') || uri.startsWith('.')
      uri = "file://#uri"

    console.log 'open' uri
    await pdfjsLib.getDocument(uri).promise
      @pdf?.destroy!
      @pdf = ..
      ..uri = uri
      if uri.startsWith('file://')
        @watcher.single uri
      else
        @watcher.clear!
    @refresh!
    @

  reload: ->
    if @pdf?uri then @open that

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

      page.render do
        canvasContext: ctx
        viewport: viewport
      .promise.then ~>
        {page, canvas}

  goto-page: (page-num) ->
    @selected-page = page-num
    @pages[page-num] ?= @render-page(page-num)
      ..then (page) ~> @containing-element
        @canvas?remove!
        ..append (@canvas = page.canvas)
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
    @_debounce-refresh = _.debounce @~refresh, 300
    @containing-element .on 'wheel' (ev) ~>
      if ev.ctrlKey
        if @canvas?
          z = @zoom
          @zoom -= ev.originalEvent.deltaY / 100
          @canvas.width @canvas.width() * @zoom / z
        @emit 'resizing' @canvas
        @_debounce-refresh!
        ev.preventDefault()


class SyncTeX extends EventEmitter

  (@sync-data) ->
    console.log 'synctex create'
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
        if ev.type === 'mousedown' then @emit 'synctex-goto' ht
      else
        @blur!

  @from-file = (filename) ->>
    
    txt = await SyncTeX.read-file filename  
    new SyncTeX(synctex-parser.parseSyncTex(txt))
      ..filename = filename

  @read-file = (filename) -> new Promise (resolve, reject) ->
    if filename.endsWith('.gz')
      # apply gunzip (use stream to save memory)
      require! zlib; require! 'stream-buffers'
      fs.createReadStream(filename)  .on 'error' -> reject it
      .pipe(zlib.createGunzip())     .on 'error' -> reject it
      .pipe(new streamBuffers.WritableStreamBuffer)
      .on 'finish' -> resolve @getContentsAsString('utf-8')
    else
      fs.readFile filename, 'utf-8', resolve



class SyncTeX_MixIn

  synctex-open: (filename) ->>
    @synctex-init!
    @synctex?.remove!
    @synctex = null

    @synctex = await SyncTeX.from-file filename
      @pages[@selected-page]?then @~_synctex-page
      ..on 'synctex-goto' ~> @emit 'synctex-goto' it
      @_synctex-watcher.single filename

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
        ..on 'change' @~synctex-reload

  synctex-reload: ->
    if @synctex.filename
      @synctex-open that
      @refresh!

  synctex-locate: (pdf-filename) ->
    if typeof pdf-filename != 'string' then return

    pdf-filename .= replace(/^file:\/\//, '')

    for suffix in ['.synctex.gz', '.synctex']
      try
        fn = pdf-filename.replace(/(\.pdf|)$/, suffix)
        if fs.statSync(fn).isFile! then return fn
      catch

  _synctex-page: (page) ->
    @synctex.cover page.canvas, @zoom * @resolution
    @synctex.selected-page = @selected-page



class Viewer extends ViewerCore

  open: (pdf, synctex) ->
    super pdf .then ~>
      synctex = synctex ? @synctex-locate(pdf)
      if synctex? then @synctex-open synctex
      @ui-init! || @refresh!

  ui-init: ->
    if !@_ui-init
      @goto-page 1
      @nav-bind-ui!
      @zoom-bind-ui!
      @_ui-init = true      
      

Viewer:: <<<< Nav_MixIn:: <<<< Zoom_MixIn:: <<<< SyncTeX_MixIn::



export Viewer

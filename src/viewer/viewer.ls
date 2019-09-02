{EventEmitter} = require 'events'
_ = require 'lodash'



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

  open: (filename) ->>
    console.log 'open' filename
    await pdfjsLib.getDocument(filename).promise
      @pdf?.destroy!
      @pdf = ..
      ..filename = filename
      @watcher.single filename
    @refresh!
    @

  reload: ->
    if @pdf?filename then @open that

  render-page: (page-num) ->
    canvas = $('<canvas>')
    @pdf.getPage(page-num).then (page) ~>
      viewport = page.getViewport(1)
      scale = @zoom * @resolution
      viewport = page.getViewport(scale)
      ctx = canvas.0.getContext('2d')
      canvas.0
        ..width = viewport.width ; ..height = viewport.height
        ..style.width = "#{viewport.width / @resolution}px"

      page.render do
        canvasContext: ctx
        viewport: viewport
      .then ~>
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

  @read-file = (filename, callback) !->
    require! fs
    if filename.endsWith('.gz')
      # apply gunzip (use stream to save memory)
      require! zlib; require! 'stream-buffers'
      fs.createReadStream(filename)  .on 'error' -> callback it
      .pipe(zlib.createGunzip())     .on 'error' -> callback it
      .pipe(new streamBuffers.WritableStreamBuffer)
      .on 'finish' -> callback null, @getContentsAsString('utf-8')
    else
      fs.readFile filename, 'utf-8', callback



class SyncTeX_MixIn

  synctex-open: (filename) ->
    console.log 'open synctex' filename
    @synctex-init!

    @synctex?.remove!

    err, txt <~ SyncTeX.read-file filename
    if err
      console.error "open synctex:", err
    else
      parseSyncTex txt
        @synctex = new SyncTeX(..)
          ..filename = filename
          ..on 'synctex-goto' ~> @emit 'synctex-goto' it
      @_synctex-watcher.single filename

  synctex-init: ->
    if !@_synctex-init
      @_synctex-init = true
      @on 'displayed' (page) ~>
        if @synctex?
          @synctex.blur!
          @synctex.cover page.canvas, @zoom * @resolution
          @synctex.selected-page = @selected-page
      @on 'resizing' (canvas) ~>
        @synctex?.snap canvas
      @_synctex-watcher = new FileWatcher
        ..on 'change' @~synctex-reload

  synctex-reload: ->
    if @synctex.filename
      @synctex-open that
      @refresh!

  synctex-locate: (pdf-filename) ->
    require! fs
    pdf-filename .= replace(/^file:\/\//, '')

    for suffix in ['.synctex.gz', '.synctex']
      try
        fn = pdf-filename.replace(/(\.pdf|)$/, suffix)
        if fs.statSync(fn).isFile! then return fn
      catch


class FileWatcher extends EventEmitter
  ->
    @watches = []
    if (typeof window !== 'undefined')
      window.addEventListener('unload', @~clear)
    
    @debounce-handler = _.debounce @~handler, 500

  add: (filename) !->
    filename .= replace(/^file:\/\//, '')
    require! fs
    @watches.push fs.watch(filename, {persistent: false}, @~debounce-handler)

  clear: !->
    for @watches => ..close!
    @watches = []

  single: (filename) !-> @clear! ; @add filename

  handler: (ev, filename) -> @emit 'change' {filename}




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



export Viewer, FileWatcher

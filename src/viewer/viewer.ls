{EventEmitter} = require 'events'
_ = require 'lodash'



class ViewerCore extends EventEmitter

  (@pdf, @containing-element ? $('body')) ->
    super!
    @canvas = {}
    if @pdf?
      @canvas[1] = @render-page(1)
    @selected-page = undefined

    @zoom = 1
    @resolution = 2

    @watcher = new FileWatcher
      ..on 'change' ~> console.log window; requestAnimationFrame @~reload

  open: (filename) ->>
    console.log 'open' filename
    @pdf = await pdfjsLib.getDocument(filename).promise
      ..filename = filename
      @watcher.single filename
    @refresh!
    @

  reload: ->
    if @pdf?filename then @open that

  render-page: (page-num) ->
    canvas = $('<canvas>')
    @pdf.getPage(page-num).then (page) ~>
      @page = page
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
        canvas

  goto-page: (page-num) ->
    @selected-page = page-num
    @canvas[page-num] ?= @render-page(page-num)
      ..then (canvas) ~> @containing-element
        ..find 'canvas' .remove!
        ..append canvas
        @blob <~ canvas.0.toBlob
        @emit 'displayed' canvas

  flush: -> @canvas = {}

  refresh: -> @flush! ; if @selected-page then @goto-page that


class Nav_MixIn
  nav-bind-ui: ->
    @containing-element .keydown keydown_eh = (ev) ~>
      switch ev.code
        case "ArrowRight", "PageDown" => @next-page! ; ev.preventDefault!
        case "ArrowLeft", "PageUp"    => @prev-page! ; ev.preventDefault!
    @on 'close' ~>
      @containing-element .off 'click', click_eh

  next-page: ->
    if @pdf? && @selected-page < @pdf.num-pages
      @goto-page ++@selected-page

  prev-page: ->
    if @pdf? && @selected-page > 1
      @goto-page --@selected-page



class SyncTeX extends EventEmitter

  (@sync-data) ->
    @overlay = $('<svg xmlns="http://www.w3.org/2000/svg">')
      ..addClass('synctex-overlay')
      ..on 'mousemove mousedown' @~mouse-handler
    @highlight = $(document.createElementNS('http://www.w3.org/2000/svg', 'rect'))
      ..addClass 'highlight'
      @overlay.append ..

  cover: (canvas) ->
    canvas.parent!append @overlay
    @overlay.attr width: canvas.0.width, height: canvas.0.height
    canvas.0.getBoundingClientRect!
      @overlay.width ..width ; @overlay.height ..height

  walk: (block) ->*
    yield block
    for let b in block.blocks
      yield from @walk(b)

  hit-test: (block, point) !->*
    w = @walk(block)
    while !(cur = w.next!).done
      b = cur.value
      if @hit-test-shallow(b, point) then yield b

  hit-test-shallow: (block, point) ->
    d = 2
    (block.left - d) <= point.x <= (block.left + block.width + d) && \
    (block.bottom - block.height - d) <= point.y <= (block.bottom + d)

  hit-test-single: (block, point) ->
    ht = @hit-test(block, point)
    while !(cur = ht.next!).done
      if cur.value?type == 'horizontal'
        b = cur.value
    b

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
      p = {x: ev.offsetX, y: ev.offsetY}
      if (ht = @hit-test-single(@sync-data.pages[page-num], p))?
        @focus ht
        if ev.type === 'mousedown' then @emit 'synctex-goto' ht
      else
        @blur!


class SyncTeX_MixIn

  synctex-open: (filename) ->
    @synctex-init!

    require! fs
    err, txt <~ @_read filename
    if err
      console.error "open synctex:", err
    else
      parseSyncTex txt
        @synctex = new SyncTeX(..)
          ..filename = filename
          ..on 'synctex-goto' ~> @emit 'synctex-goto' it

  _read: (filename, callback) !->
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

  synctex-init: ->
    if !@_synctex-init
      @_synctex-init = true
      @on 'displayed' (canvas) ~>
        if @synctex?
          @synctex.blur!
          @synctex.cover canvas
          @synctex.selected-page = @selected-page


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
      if synctex? then @synctex-open synctex
      @ui-init! || @refresh!

  ui-init: ->
    if !@_ui-init
      @goto-page 1
      @nav-bind-ui!
      @_ui-init = true      
      

Viewer:: <<<< Nav_MixIn:: <<<< SyncTeX_MixIn::



export Viewer

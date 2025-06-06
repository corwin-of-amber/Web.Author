node_require = global.require ? -> {}
fs = node_require 'fs'
require! { 
    events: { EventEmitter }
    jquery: $
    lodash: _
    'pdfjs-dist': pdfjsLib
    '../infra/volume': { Volume }
    '../infra/fs-watch.ls': { FileWatcher }
    '../infra/non-reentrant.ls': non-reentrant
    '../infra/ongoing.ls': { global-tasks }
    '../infra/ui-pan-zoom': { Zoom }
    '../ide/problems.ls': { safe }
    './synctex.ls': { SyncTeX }
    './overlay.ls': { TextSearchOverlay }
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

    @text-overlay = new TextSearchOverlay
      @on 'open' (pdf) ~> ..pdf = pdf
      @on 'displayed' (page) ~>
        ..cover page.canvas, @zoom * @resolution
        ..highlight-matches @selected-page
      @on 'resizing' (canvas) ~> ..snap canvas

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
    else if locator instanceof URL
      locator = {volume: null, filename: locator.href}
    else if typeof locator == 'string'
      locator = {volume: null, filename: locator}

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
    @emit 'open', @pdf
    @selected-page = Math.min(page, @pdf.num-pages)
    @refresh!
    @

  fit: ->
    @containingElement.0.scrollTo 0, 0

  _to-uri: (loc) ->
    loc = Volume.externSync(loc)
    if loc.volume == fs then "file://#{loc.filename}" else loc.filename

  reload: ->
    if @loc then @open that, @selected-page

  render-page: (page-num) ->
    canvas = $('<canvas>')
    @pdf.getPage(page-num).then (page) ~>
      r = @resolution
      viewport = page.getViewport({scale: @zoom})
      ctx = canvas.0.getContext('2d', {alpha: false})
      ctx.scale r, r
      canvas.0
        ..width = Math.floor(viewport.width * r)
        ..height = Math.floor(viewport.height * r)
        ..style.width = "#{Math.floor(viewport.width)}px"  # height is adjusted by the browser

      @_ongoing?cancel!
      @_ongoing = page.render do
        canvasContext: ctx
        transform: [r, 0, 0, r, 0, 0]
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
        @zoom = z; @flush!  # @todo maybe not always flush?
        @emit 'resizing' @canvas
        @_debounce-refresh!
    @_debounce-refresh = _.debounce @~zoom-refresh, 300

  zoom-refresh: ->
    # no use refreshing once it gets too small
    if @zoom >= 1 then @refresh!


class Pan_MixIn

  pan-clearance: {left: 4, right: -4, top: 20, bottom: -20}

  pan-into-view: ($el) ->
    ce-box = @containing-element.0.getBoundingClientRect!
    el-box = $el.0.getBoundingClientRect!
    clearance = @pan-clearance
    how-far = {[.., el-box[..] - ce-box[..] - clearance[..]] \
               for <[left right top bottom]>}

    drift = (start, end) -> Math.min(start, Math.max(0, end))
    how-far
      adjust = {x: drift(..left, ..right), y: drift(..top, ..bottom)}

    @containing-element.0.scrollBy adjust.x, adjust.y



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

  synctex-forward: (loc /* {filename, line} */) ->>
    if (lu = @synctex?lookup(loc))?
      if lu.page != @selected-page
        await @goto-page lu.page
      @_synctex-cursor lu.block

  _synctex-cursor: (block) ->
    @synctex.focus @synctex.cursor, block
      @pan-into-view ..

  _synctex-page: (page) ->
    if @synctex?
      @synctex.blur!
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
  
  _scroll:~
    -> @containingElement.0.{scrollLeft, scrollTop}
    (v) -> @containingElement.0 <<< v{scrollLeft, scrollTop}

  state:~
    -> {@loc, @selected-page, scroll: @_scroll}
    (v) ->
      safe ~>>
        if (v.loc) then await @open v.loc, v.selected-page
        if (v.scroll) then @_scroll = that


PDFViewer:: <<<< Nav_MixIn:: <<<< Zoom_MixIn:: <<<< Pan_MixIn:: <<<< SyncTeX_MixIn::



export PDFViewer

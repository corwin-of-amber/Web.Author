node_require = global.require ? -> {}
  fs = .. 'fs'
require! { 
  events: { EventEmitter }
  jquery: $
  lodash: _
  'synctex-js': { parser: synctex-parser }
}


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

  _block-dump: (block, with-elements=true) !->  # for debugging
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


export { SyncTeX }
require! { 
  events: { EventEmitter }
  jquery: $
  '../infra/text-search.ls': text-search
}


class Overlay
  -> @$el = $svg('svg')

  cover: (canvas, scale) ->
    canvas.parent!append @$el
    @size = {x: canvas.0.width / scale, y: canvas.0.height / scale}
    @$el.attr viewBox: "0 0 #{@size.x} #{@size.y}"
    @snap canvas ; @

  snap: (canvas) !->
    @$el.0.style.width = canvas.0.style.width

  clear: -> @$el.empty! ; @
  remove: -> @$el.remove! ; @

  make-rect: -> $svg('rect')
    @$el.append ..


class TextHighlightOverlay extends Overlay
  (@styles) -> super! ; @$el.addClass 'highlight-overlay'

  mark: (item) ->
    @make-rect! .addClass 'mark' .attr @_item-bbox(item)

  _item-bbox: (item) ->
    t = item.transform
    @styles?[item.fontName]
      hrat = if ..?ascent then 1 - ..descent / ..ascent else 1
    @_from-bottom({x: t[4], y: t[5], item.width, item.height})
      ..height *= hrat

  _from-bottom: (rect) ->
    {...rect, y: @size.y - rect.y - rect.height}


class PDFTextContent
  (@pdf, @styles = {}) ->
    @pages = {}
    @_ready = Promise.all [1 to @pdf.numPages].map ~>>
      @pages[it] = await (await @pdf.getPage(it)).getTextContent!
        @styles <<< ..styles


class TextSearchOverlay extends TextHighlightOverlay
  (@pdf) -> super {}; @age = 0

  populate: -> if @pdf
    @content = new PDFTextContent(@pdf, @styles)
      return .._ready

  mark-matched: (matched) ->
    @make-rect! .addClass 'mark' .attr @_matched-bbox(matched)

  highlight-matches: (page, matches = @matches ? []) ->
    @clear!
    for matched in matches
      if matched.page == page then @mark-matched matched

  search-and-highlight-naive: (text, page) ->>
    age = ++@age
    results = await @search-naive(text)
    if age == @age
      @highlight-matches page, results

  search-naive: (text) ->> if @pdf
    await @content?_ready ? @populate!
    @matches = [{page: +i, ...@_match-naive(item, text)} \
                for i, page of @content.pages for item in page.items] \
               .filter((.item?))

  _match-naive: (item, substr) ->
    re = text-search.Query.promote(substr, 'i').re
    mo = re.exec(item.str)
    if mo then {item, mo}

  _matched-bbox: ({item, mo}) ->
    bbox = @_item-bbox(item)
    lrat = mo.index / item.str.length
    wrat = Math.min 1, (mo.0.length + 2) / item.str.length
    {...bbox, x: bbox.x + bbox.width * lrat, width: bbox.width * wrat}


$svg = (tag-name) ->
  $(document.createElementNS('http://www.w3.org/2000/svg', tag-name))


export { Overlay, TextHighlightOverlay, TextSearchOverlay }
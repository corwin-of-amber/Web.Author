require! {
  fs
  '../html-viewer': { HTMLDocument }
}


class WordPressTheme

  (@template, @preamble = "/build/wp/preamble.js") ->

  wp-convert-shortcodes: ->
    it.replace(/\[/g, '<').replace(/\]/g, '>')  # @todo

  render: (source) ->
    template = fs.readFileSync(@template, 'utf-8')
    site-content = @wp-convert-shortcodes source
    new HTMLDocument(template.replace('{{site__content}}', """
        <script src="#{@preamble}"></script>      
        #{site-content}"""))


export { WordPressTheme }
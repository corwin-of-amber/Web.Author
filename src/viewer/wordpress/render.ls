require! {
  fs
  '../html-viewer': { HTMLDocument }
}


class WordPressTheme

  (@template, @preamble = "/build/wp/preamble.js") ->

  wp-convert-shortcodes: ->
    it.replace(/\[/g, '<').replace(/\]/g, '>')  # @todo

  render: (filename) ->
    template = fs.readFileSync(@template, 'utf-8')
    site-content = @wp-convert-shortcodes fs.readFileSync(filename, 'utf-8')
    new HTMLDocument(template.replace('{{site__content}}', """
        <script src="#{@preamble}"></script>      
        #{site-content}"""))


export { WordPressTheme }
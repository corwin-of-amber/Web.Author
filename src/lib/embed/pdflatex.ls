require! {
  fs, path, tempy
  'promisify-child-process': promisify-child-process
}



class EmbedPdf

  (@input-filename) ->
    @_promise = void

  promise:~
    ->
      if @_promise? then return @_promise
      @output-filename = @mktemp!
      @_promise = promisify-child-process.spawn('gs',
          ['-q', '-dNOPAUSE', '-dBATCH', '-sDEVICE=pngalpha', '-r600x600',
           "-sOutputFile=#{@output-filename}", @input-filename],
          {encoding: 'utf-8'})
      .then (result) ~>
        @_gs-result = result
        new Blob([fs.readFileSync(@output-filename)])

  mktemp: -> tempy.file({extension: '.png'})

  cleanup: -> if @output-filename then fs.remove @output-filename



class EmbedPdfLatex

  (@input-filename) ->
    @_promise = void

  promise:~
    ->
      if @_promise? then return @_promise
      @output-dir = @mktemp!
      @jobname = 'pdfembed'
      @output-filename = path.join(@output-dir, "#{@jobname}.pdf")
      @_promise = promisify-child-process.spawn('pdflatex',
          ['-file-line-error', '-interaction', 'nonstopmode', '-output-dir',
          @output-dir, '-jobname', @jobname, @input-filename],
          {encoding: 'utf-8'})
      .then (result) ~>
        @_pdflatex-result = result
        @_embed-pdf = new EmbedPdf(@output-filename)
        @_embed-pdf.promise

  mktemp: -> tempy.directory!

  cleanup: ->
    if @output-dir then fs.remove @output-dir
    @_embed-pdf?cleanup!


/**
 * Like EmbedPdfLatex, but gets the LaTeX source as a string.
 */
class EmbedPdfLatexDirect

  (@latex-source-text) ->
    @_promise = void

  promise:~
    ->
      if @_promise? then return @_promise
      @latex-file = @mktemp!
        fs.writeFileSync .., @latex-source-text
      @_embed-pdflatex = new EmbedPdfLatex(@latex-file)
      @_promise = @_embed-pdflatex.promise

  mktemp: -> tempy.file({extension: '.tex'})

  cleanup: ->
    if @latex-file then fs.remove @latex-file
    @_embed-pdflatex?cleanup!



export EmbedPdf, EmbedPdfLatex, EmbedPdfLatexDirect

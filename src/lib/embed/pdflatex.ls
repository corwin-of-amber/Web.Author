require! fs
require! mkdirp
require! path
child-process-promise = require 'child-process-promise'



class EmbedPdf

  (@input-filename) ->
    @_promise = void

  promise:~
    ->
      if @_promise? then return @_promise
      @output-filename = @mktemp!
      @_promise = child-process-promise.spawn('gs',
          ['-q', '-dNOPAUSE', '-dBATCH', '-sDEVICE=pngalpha', '-r600x600',
           "-sOutputFile=#{@output-filename}", @input-filename],
          {capture: <[ stdout stderr ]>})
      .then (result) ~>
        @_gs-result = result
        new Blob([fs.readFileSync(@output-filename)])

  mktemp: -> '/tmp/embed-pdf.png'  # TODO



class EmbedPdfLatex

  (@input-filename) ->
    @_promise = void

  promise:~
    ->
      if @_promise? then return @_promise
      @output-dir = @mktemp!
        mkdirp.sync ..
      @jobname = 'pdfembed'
      @output-filename = path.join(@output-dir, "#{@jobname}.pdf")
      @promise = child-process-promise.spawn('pdflatex',
          ['-file-line-error', '-interaction', 'nonstopmode', '-output-dir',
          @output-dir, '-jobname', @jobname, @input-filename],
          {capture: <[ stdout stderr ]>})
      .then (result) ~>
        @_pdflatex-result = result
        @_embed-pdf = new EmbedPdf(@output-filename)
        @_embed-pdf.promise

  mktemp: -> '/tmp/embed-pdflatex'  # TODO


export EmbedPdf, EmbedPdfLatex

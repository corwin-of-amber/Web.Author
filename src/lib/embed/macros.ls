require! find

{consume-next} = Traversal
{consume-optarg} = Commands


RegExp.escape = (s) ->
    s.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')


commands =
  includegraphics: ->
    opts = consume-optarg it
    image-fn = consume-next it .text!
    /* more thought should be put into path resolution but that should be enough for now */
    q = RegExp.escape
    image-path = find.fileSync(//#{q image-fn}(.(png|pdf))?$//, '.')?0 ? image-fn

    $ '<img>'
      if /.pdf$/.exec(image-path)
        new EmbedPdf(image-path).promise.then (blob) ->
          ..attr 'src' URL.createObjectURL(blob)
      else
        ..attr 'src' "/#{image-path}"
      process-image-options .., opts

  embedlatex: ->
    opts = consume-optarg it
    tex-fn = consume-next it .text!
    /* more thought should be put into path resolution but that should be enough for now */
    q = RegExp.escape
    tex-path = find.fileSync(//#{q tex-fn}(.tex)?$//, '.')?0 ? tex-fn

    $ '<img>'
      new EmbedPdfLatex(tex-path).promise.then (blob) ->
        ..attr 'src' URL.createObjectURL(blob)
      process-image-options .., opts


process-image-options = (img, opts) ->
  /* opts parsing should be generalized */
  if opts?
    if (mo = /width\s*=\s*([^,]*)/.exec opts.text!)?
      img.css 'width' mo.1



@commands <<< commands

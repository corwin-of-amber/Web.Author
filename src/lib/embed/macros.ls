require! fs
require! find

{consume-next, peek-next, containing-document, env} = Traversal
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
      (e = new EmbedPdfLatex(tex-path)).promise.then (blob) ->
        ..attr 'src' URL.createObjectURL(blob)
      .catch -> latex-report-error 'pdflatex', it
      .finally -> e.cleanup!
      process-image-options .., opts

  includelatex: ->
    opts = consume-optarg it
    tex-fn = consume-next it .text!
    /* more thought should be put into path resolution but that should be enough for now */
    q = RegExp.escape
    tex-path = find.fileSync(//#{q tex-fn}(.tex)?$//, '.')?0 ? tex-fn
    content = fs.readFileSync(tex-path)

    preamble = latex-preamble-getoption it
    console.log preamble
    document =
      LATEX_DOCUMENT_TEMPLATE {preamble, body: content}

    $ '<img>'
      (e = new EmbedPdfLatexDirect(document)).promise.then (blob) ->
        ..attr 'src' URL.createObjectURL(blob)
      .catch -> latex-report-error 'pdflatex', it
      .finally -> e.cleanup!
      process-image-options .., opts


environments =
  latex: ->
    name = peek-next it, (-> it)  # should be {latex}
    opts = consume-optarg name
    content = $ '<span>' .append env it
      @verbatim ..children!
    if opts.text! == 'preamble'
      return latex-preamble-mkoption content
    preamble = latex-preamble-getoption it
    document =
      LATEX_DOCUMENT_TEMPLATE {preamble, body: content.text!}
    $ '<img>'
      (e = new EmbedPdfLatexDirect(document)).promise.then (blob) ->
        ..attr 'src' URL.createObjectURL(blob)
      .catch -> latex-report-error 'pdflatex', it
      .finally -> e.cleanup!
      process-image-options .., opts


latex-preamble-mkoption = (content) ->
  $ '<span>' .add-class 'option' .attr 'name', 'latex-preamble'
    ..text content.text!

latex-preamble-getoption = (dom) ->
  $(containing-document(dom)).find('.option[name=latex-preamble]').text!
# TODO get from where?

latex-report-error = (label, err) ->
  console.error "[#{label}]", err
  console.error err.stdout

LATEX_DOCUMENT_TEMPLATE = (d) -> """
\\documentclass{standalone}
#{d.preamble}
\\begin{document}
#{d.body}
\\end{document}
"""


process-image-options = (img, opts) ->
  /* opts parsing should be generalized */
  if opts?
    if (mo = /width\s*=\s*([^,]*)/.exec opts.text!)?
      img.css 'width' mo.1



@commands <<< commands
@environments <<< environments

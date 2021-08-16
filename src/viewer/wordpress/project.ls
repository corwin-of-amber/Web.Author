require! {
  fs
  path
  events: { EventEmitter }
  '../../net/mysql': { MySQLProject }
}


class WordPressProject extends EventEmitter
    (@base-dir, @table-names = {}, db-connect-info, schema = DEFAULT_SCHEMA) ->
      super!
      @schema = schema.map ~> {...it, table: @table-names[it.table] || it.table}
      @data-source = new MySQLProject(db-connect-info, @schema, @base-dir)

    connect: -> @data-source.connect!

    build: (fn) ->
      source = fs.readFileSync(path.join(@base-dir, fn), 'utf-8')
      @theme.render source
        @emit 'rendered', {content: .., content-type: 'text/html'}


DEFAULT_SCHEMA = [ \
    {table: 'wp_posts', nameField: 'post_name', \
     titleField: 'post_title', contentField: 'post_content', \
     whereCond: 'post_type = "page"', type: 'wp'}]


export { WordPressProject }
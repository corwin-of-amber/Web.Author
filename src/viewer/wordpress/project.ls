require! {
  '../../net/mysql': { MySQLProject }
}


class WordPressProject
    (@base-dir, @table-names = {}, db-connect-info, schema = DEFAULT_SCHEMA) ->
      @schema = schema.map ~> {...it, table: @table-names[it.table] || it.table}
      @data-source = new MySQLProject(db-connect-info, @schema, @base-dir)

    connect: -> @data-source.connect!


DEFAULT_SCHEMA = [ \
    {table: 'wp_posts', nameField: 'post_name', \
     titleField: 'post_title', contentField: 'post_content', \
     whereCond: 'post_type = "page"', type: 'wp'}]


export { WordPressProject }
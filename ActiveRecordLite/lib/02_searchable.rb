require_relative 'db_connection'
require_relative '01_sql_object'

module Searchable
  def where(params)
    where_arr = params.keys.map {|key| "#{key} = ?"}
    where_line = where_arr.join("AND ")
    xd =DBConnection.execute(<<-SQL, *params.values)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        #{where_line}
    SQL
    parse_all(xd)
  end
end

class SQLObject
  extend Searchable
  # Mixin Searchable here...
end

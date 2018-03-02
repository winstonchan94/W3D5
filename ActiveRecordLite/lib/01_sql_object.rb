require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    return @columns if @columns
    data = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
      LIMIT
        0
    SQL
    @columns = data.first.map!(&:to_sym)
  end

  def self.finalize!
    self.columns.each do |column|
      define_method(column) do
        self.attributes[column]
      end
      define_method("#{column}=") do |value|
        self.attributes[column] = value
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || "#{self}".tableize
  end

  def self.all
    stuff = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
    SQL
    self.parse_all(stuff)
  end

  def self.parse_all(results)
    results.map do |thing|
      self.new(thing)
    end
  end

  def self.find(id)
    results = DBConnection.execute(<<-SQL, id)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        #{self.table_name}.id = ?
    SQL

    parse_all(results).first
  end

  def initialize(params = {})
    params.keys.each do |key|
      sym_key = key.to_sym
      raise "unknown attribute '#{key}'" unless self.class.columns.include?(sym_key)
      self.send("#{key}=", params[key])
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map do |column|
      self.send(column)
    end
    # ...
  end

  def insert
    col_names = self.class.columns.drop(1).map(&:to_s).join(", ")
    question_marks = (['?'] * self.class.columns.drop(1).length).join(', ')
    DBConnection.execute(<<-SQL, *attribute_values.drop(1))
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{question_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    set_line_arr = self.class.columns.drop(1).map do |attr_name|
      "#{attr_name} = ?"
    end
    set_line = set_line_arr.join(', ')
    DBConnection.execute(<<-SQL, *attribute_values.drop(1), self.id)
      UPDATE
        #{self.class.table_name}
      SET
        #{set_line}
      WHERE
        id = ?
      SQL
    # ...
  end

  def save
    if self.class.find(self.id)
      update
    else
      insert
    end 
    # ...
  end
end

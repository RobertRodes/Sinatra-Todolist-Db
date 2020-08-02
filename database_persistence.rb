require 'pg'

class DatabasePersistence
  def initialize(logger)
    @logger = logger
    @db = if Sinatra::Base.production?
      PG.connect(ENV['DATABASE_URL'])
    else
      PG.connect(dbname: "todos")
    end
  end

  def all_lists
    sql = 'SELECT * FROM lists'
    query(sql).map do |row|
      list_id = row['id'].to_i
      {id: list_id, name: row['name'], todos: find_list_todos(list_id)}
    end
  end

  def create_list(list_name)
    sql = 'INSERT INTO lists (name) values ($1)'
    query(sql, list_name)
  end

  def delete_list(id)
    query('DELETE FROM todos WHERE list_id = $1', id)
    query('DELETE FROM lists WHERE id = $1', id)
  end

  def find_list(list_id)
    sql = 'SELECT DISTINCT name FROM lists WHERE id = $1'
    name = query(sql, list_id).first['name']
    {id: list_id, name: name, todos: find_list_todos(list_id)}    
  end

  def update_list(id, new_name)
    sql = 'UPDATE lists SET name = $1 WHERE id = $2'
    query(sql, new_name, id)
  end

  def create_todo(list_id, name)
    sql = 'INSERT INTO todos (list_id, name) VALUES ($1, $2)'
    query(sql, list_id, name)
  end

  def delete_todo(list_id, todo_id)
    sql = 'DELETE FROM todos WHERE list_id = $1 AND id = $2'
    query(sql, list_id, todo_id)
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = 'UPDATE todos SET completed = $3 WHERE list_id = $1 and id = $2'
    query(sql, list_id, todo_id, new_status)
  end

  def complete_all_todos(list_id)
    sql = 'UPDATE todos SET completed = true WHERE list_id = $1'
    query(sql, list_id)
  end

  def disconnect
    @db.close
  end

  private

  def find_list_todos(list_id)
    sql_todos = 'SELECT * FROM todos WHERE list_id = $1'
    query(sql_todos, list_id).map do |todo|
      {
        id: todo['id'].to_i, 
        name: todo['name'], 
        completed: todo['completed'] == 't'
      }
    end
  end

  def query(sql, *params)
    @logger.info "\n    sql: #{sql}; params: #{params}"
  @db.exec_params(sql, params)
end

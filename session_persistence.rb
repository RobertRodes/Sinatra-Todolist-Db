class SessionPersistence
  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def all_lists
    @session[:lists]
  end

  def create_list(list_name)
    id = next_id(@session[:lists])
    @session[:lists] << {id: id, name: list_name, todos: []}
  end

  def delete_list(id)
    @session[:lists].delete_if { |list| list[:id] == id }
  end

  def find_list(id)
    @session[:lists].find { |list| list[:id] == id }
  end

  def update_list(id, new_name)
    find_list(id)[:name] = new_name
  end

  def create_todo(list_id, name)
    list = find_list(list_id)
    id = next_id(list[:todos])
    list[:todos] << { id: id, name: name, completed: false }    
  end

  def delete_todo(list_id, todo_id)
    find_list(list_id)[:todos].delete_if { |todo| todo[:id] == todo_id }
  end

  def update_todo_status(list_id, todo_id, new_status)
    todo = find_list(list_id)[:todos].find { |todo| todo[:id] == todo_id }
    todo[:completed] = new_status
  end

  def complete_all_todos(id)
    find_list(id)[:todos].each { |todo| todo[:completed] = true }
  end

  private

  def next_id(items)
    (items.map { |item| item[:id] }.max || -1) + 1
  end
end

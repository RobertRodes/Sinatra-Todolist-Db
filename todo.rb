require 'sinatra'
require 'sinatra/content_for'
require 'tilt/erubis'
require_relative 'database_persistence'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload 'database_persistence.rb'
end

before do
  @storage = DatabasePersistence.new(logger)
end

after do
  @storage.disconnect
end

helpers do
  def complete?(list)
    !list[:todos].empty? && open_todo_count(list).zero?
  end

  def get_todo(id)
    @list[:todos].find { |todo| todo[:id] == id }
  end

  def list_classes(list)
    'complete' if complete?(list)
  end

  def open_todo_count(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def sorted_lists(lists)
    complete_lists, incomplete_lists =
      lists.partition { |list| complete?(list) }

    incomplete_lists.each { |list| yield list }
    complete_lists.each { |list| yield list }
  end

  def sorted_todos(todos)
    complete_todos, incomplete_todos =
      todos.partition { |todo| todo[:completed] }
    incomplete_todos.each { |todo| yield todo }
    complete_todos.each { |todo| yield todo }
  end

  def todos_count(list)
    list[:todos].size
  end
end

# Apply validation logic, return error message or nil if no error
def error_for_list(name)
  if !(1..100).cover?(name.size)
    'List name must have from 1 to 100 characters.'
  elsif @storage.all_lists.any? { |list| list[:name] == name }
    "List name \"#{name}\" is already in use."
  end
end

def error_for_todo(name)
  'Todo name must have from 1 to 100 characters.' unless
    (1..100).cover?(name.size)
end

def load_list(id)
  list = @storage.find_list(id)
  return list if list
  session[:error] = "List '#{id}' not found"
  redirect '/lists'
end

get '/' do
  redirect '/lists'
end

# GET   / or /lists     -> view all lists
# GET   /lists/new      -> new list form
# POST  /lists          -> create new list
# GET ` /lists/1        -> view a single list
# GET   /lists/1/edit   -> edit an existing list
# POST  /lists/1        -> update an existing list (save edits)

# View all todo lists
get '/lists' do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# Show new todo list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Create a new todo list
post '/lists' do
  @lists = @storage.all_lists
  list_name = params[:list_name].strip
  error = error_for_list(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_list(list_name)
    # @lists << {id: next_list_id(@lists), name: list_name, todos: []}
    session[:success] = "List \"#{list_name}\"successfully added."
    redirect '/lists'
  end
end

# View a single todo list
get '/lists/:id' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :list, layout: :layout
end

# Edit an existing todo list
get '/lists/:id/edit' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :edit_list, layout: :layout
end

# Update an existing todo list (save edits)
post '/lists/:id' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  list_name = params[:list_name].strip
  if list_name == @list[:name]
    redirect "/lists/#{@list_id}"
  else
    error = error_for_list(list_name)
    if error
      session[:error] = error
      erb :edit_list, layout: :layout
    else
      @storage.update_list(@list_id, list_name)
      session[:success] = 'List successfully updated.'
      redirect "/lists/#{@list_id}"
    end
  end
end

# Delete a todo list
post '/lists/:id/destroy' do
  @list_id = params[:id].to_i
  name = @storage.find_list(@list_id)[:name]
  @storage.delete_list(@list_id)
  session[:success] = "List \"#{name}\" deleted."
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    '/lists'
  else
    redirect '/lists'
  end
end

# Add a new todo to a todo list
post '/lists/:list_id/todos' do
  todo_name = params[:todo].strip
  error = error_for_todo(todo_name)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @storage.create_todo(params[:list_id].to_i, todo_name)
    session[:success] = "Todo \"#{todo_name}\" added."
    redirect "/lists/#{params[:list_id]}"
  end
end

# Delete a todo from a todo list
post '/lists/:list_id/todos/:todo_id/destroy' do
  @storage.delete_todo(params[:list_id].to_i, params[:todo_id].to_i)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    redirect "/lists/#{@list_id}"
  end
end

# Complete or uncomplete a todo
post '/lists/:list_id/todos/:todo_id' do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  @storage.update_todo_status(list_id, todo_id, params[:completed] == 'true')
  list = load_list(list_id)
  session[:success] = 
    "All \"#{list[:name]}\" todos completed." if complete?(list)
  redirect "/lists/#{list_id}"
end

# Complete all todos
post '/lists/:list_id/complete_all_todos' do
  list_id = params[:list_id].to_i
  @storage.complete_all_todos(list_id)
  list = load_list(list_id)
  session[:success] = "All \"#{list[:name]}\" todos completed."
  redirect "/lists/#{list_id}"
end

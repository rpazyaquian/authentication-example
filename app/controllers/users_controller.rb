class UsersController < ApplicationController
  def index
    @users = User.all
    @login_user = User.new
    session[:user_id] = 1
    @logged_in_user = User.find(session[:user_id]) if session[:user_id]
  end
end
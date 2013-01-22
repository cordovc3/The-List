class UsersController < ApplicationController

  skip_before_filter :require_login, :except => [:gift,:profile]

  #for adding a new user
	def new
	  @user = User.new
	end


	def create
		@token = @token = params[:token]
		
	  if User.where(:gift_token => @token).count == 0
	  	@user = User.find_or_initialize_by_id(params[:user].merge(:gift_token => @token))
	  else
	  	render "new"
	  end
	  
	  if @user.save

	    redirect_to root_url
	  else
	    render "new"
	  end
	end

  def send_gift(email,karma,new_gift_token,sender)
  	new_gift_token = SecureRandom.urlsafe_base64
		@new_user = User.new
		@new_user.save
	  Invite.gift(email, karma, new_gift_token, sender).deliver
  end

	def user
    @user = User.find_by_username(params[:username])

    @posts = Post
    .where(:user_id => User.find_by_username(params[:username]).id)
    .joins("LEFT JOIN votes ON posts.id = votes.post_id")
    .select("posts.id," +
      "sum(if(direction = 0, value, if(direction is null, 0, -value))) as score," +
      "posts.created_at," +
      "url," +
      "title," +
      "posts.user_id," +
      "comment_count")
    .group("posts.id")
  end
end

class PostsController < ApplicationController

  skip_before_filter :require_login, :only => [:index, :show, :recent, :top]
	before_filter :free_invites, :only => [:index]

  @@posts = Post
    .joins("LEFT JOIN votes ON posts.id = votes.post_id")
    .select("posts.id," +
      "sum(if(vote_type = 0, if(direction = 0, value, -value),0)) as score," +
      "sum(if(vote_type = 0, if(direction = 0, value, 0),0)) as upvotes," +
      "sum(if(vote_type = 0, if(direction = 1, -value, 0),0)) as downvotes," +
      "posts.created_at," +
      "url," +
      "title," +
      "posts.user_id")
    .group("posts.id")

  # GET /posts
  # GET /posts.json
  def index
    @page = params[:page]

    @posts = @@posts
      .order("log10(abs(sum(if(vote_type = 0, if(direction = 0, value, if(direction is null, 0, -value)),0))) + 1) * sign(sum(if(vote_type = 0, if(direction = 0, value, if(direction is null, 0, -value)),0))) + (unix_timestamp(posts.created_at) / 300000) DESC")
      .page(@page)

    if @page
      @multiplier = @page.to_i - 1
    else
      @multiplier = 0
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @posts }
    end
  end

  # GET /posts/1
  # GET /posts/1.json
  def show
    @post = Post.find(params[:id])

    @comments = Comment
      .joins("LEFT JOIN votes ON comments.id = votes.post_id")
      .select("comments.id," +
        "sum(if(vote_type = 1, if(direction = 0, value, if(direction is null, 0, -value)),0)) as score," +
        "sum(if(vote_type = 1, if(direction = 0, value, 0),0)) as upvotes," +
        "sum(if(vote_type = 1, if(direction = 1, -value, 0),0)) as downvotes," +
        "comments.created_at," +
        "body," +
        "comments.user_id")
      .where(:post_id => @post.id, :comment_type => 0)
      .group("comments.id")

    @comment = Comment.new

    @post = Post
      .joins("LEFT JOIN votes ON posts.id = votes.post_id")
      .select("posts.id," +
        "sum(if(vote_type = 0, if(direction = 0, value, if(direction is null, 0, -value)),0)) as score," +
        "sum(if(vote_type = 0, if(direction = 0, value, 0),0)) as upvotes," +
        "sum(if(vote_type = 0, if(direction = 1, -value, 0),0)) as downvotes," +
        "posts.created_at," +
        "url," +
        "title," +
        "posts.user_id").find(params[:id])

    if current_user
      if Vote.where(:user_id => current_user.id, :post_id => @post.id, :direction => 0, :vote_type => 0).count > 0
        @active = ' upactive'
      elsif Vote.where(:user_id => current_user.id, :post_id => @post.id, :direction => 1, :vote_type => 0).count > 0
        @active = ' downactive'
      end

      found_vote = Vote.find_by_post_id_and_user_id_and_vote_type(@post.id, current_user.id, 0)

      if found_vote
        @value = found_vote.value
      else
     	  @value = current_user.karma * 0.02
     	  @value = 1 if @value < 1
      end


      if current_user.id == @post.user_id.to_i
        @active += " owner"
      end
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @post }
    end
  end

  # GET /posts/new
  # GET /posts/new.json
  def new
    @post = Post.new

    @threshold = (current_user.karma * 0.02).round

    @threshold = 4 if @threshold < 4

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @post }
    end
  end

  # POST /posts
  # POST /posts.json
  def create
    @post = Post.new(params[:post].merge(:user_id => current_user.id))

    @threshold = (current_user.karma * 0.02).round

    @threshold = 4 if @threshold < 4

    respond_to do |format|
      if @post.save
	      @mixpanel = Mixpanel::Tracker.new "15c792135a188f39a0b6875a46a28d74"
    	  @mixpanel.track 'post', { :username => current_user.username }
        @new_vote = Vote.new(:post_id => @post.id, :user_id => current_user.id, :vote_type => 0, :direction => 0, :value => @threshold)

        if @new_vote.save
          User.find(current_user.id).update_attributes({
        	  :karma => current_user.karma - @threshold
      	  })
    	  end

        format.html { redirect_to @post }
        format.json { render json: @post, status: :created, location: @post }
      else
        format.html { render action: "new" }
        format.json { render json: @post.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /posts/1
  # PUT /posts/1.json
  def update
    @post = Post.find(params[:id])

    respond_to do |format|
      if @post.update_attributes(params[:post])
        format.html { redirect_to @post }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @post.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /posts/1
  # DELETE /posts/1.json
  def destroy
    @post = Post.find(params[:id])
    @post.destroy

    respond_to do |format|
      format.html { redirect_to posts_url }
      format.json { head :no_content }
    end
  end

  def recent
    @page = params[:page]

    if @page
      @multiplier = @page.to_i - 1
    else
      @multiplier = 0
    end

    @posts = @@posts
      .order("posts.created_at DESC")
      .page(@page)

    respond_to do |format|
      format.html { render "/posts/index" }
      format.json { render json: @posts }
      format.rss { render :layout => false }
    end
  end

  def top
    @posts = @@posts
      .joins("LEFT JOIN votes ON posts.id = votes.post_id")
      .select("posts.id," +
        "sum(if(vote_type = 0, if(direction = 0, value, if(direction is null, 0, -value)),0)) as score," +
        "sum(if(vote_type = 0, if(direction = 0, value, 0),0)) as upvotes," +
        "sum(if(vote_type = 0, if(direction = 1, -value, 0),0)) as downvotes," +
        "posts.created_at," +
        "url," +
        "title," +
        "posts.user_id")
      .group("posts.id")
      .limit(15)
      .order("sum(if(vote_type = 0, if(direction = 0, value, if(direction is null, 0, -value)),0)) DESC")

    @users = User
      .where("username IS NOT NULL")
      .limit(15)
      .order("karma DESC")

    respond_to do |format|
      format.html { render "/posts/top" }
      format.json { render json: @posts }
    end
  end

  def fetch_title
    @title = Pismo::Document.new(params[:url]).title

    respond_to do |format|
      format.html { render :layout => false }
    end
  end
end

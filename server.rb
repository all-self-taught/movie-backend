# server.rb
require 'sinatra'
require 'sinatra/activerecord'
require 'sinatra/cross_origin'
require 'net/http'
require 'bcrypt'

KEY = '38194662'
OMDBAPI_BASE_URL = 'www.omdbapi.com'

set :database_file, 'config/database.yml'

class Movie < ActiveRecord::Base
  has_many :user_movie_ratings
  has_many :users, through: :user_movie_ratings
end

class UserMovieRating < ActiveRecord::Base
  belongs_to :user
  belongs_to :movie
end

class MovieSearch
  attr_accessor :movie, :user

  def initialize(movie, user)
    @title = movie['Title']
    @year = movie['Year']
    @rated = movie['Rated']
    @genre = movie['Genre']
    @imageUrl = movie['Poster']
    @director = movie['Director']
    @writer = movie['Writer']
    @actor = movie['Actors']
    @plot = movie['Plot']
    @imdbId = movie['imdbID']
    @user_feedback = UserMovieRating.joins(:movie).where(movies: {imdbId: @imdbId}, user_movie_ratings: {user_id: user.id})
  end

end

class User < ActiveRecord::Base
  include BCrypt
    has_many :user_movie_ratings
    has_many :movies, through: :user_movie_ratings

    def password
      @password ||= Password.new(password_hash)
    end

    def password=(password)
      self.password_hash = BCrypt::Password.create(password)
    end

    def generate_token!
      self.token = SecureRandom.urlsafe_base64(64)
      self.save!
    end
end

class App < Sinatra::Base

  set :bind, '0.0.0.0'

  configure do
    enable :cross_origin
  end

  before do
    response.headers['Access-Control-Allow-Origin'] = '*'
    begin
      if request.body.read(1)
        request.body.rewind
        @request_payload = JSON.parse request.body.read, { symbolize_names: true }
      end
    rescue JSON::ParserError => e
      request.body.rewind
      puts "The body #{request.body.read} was not JSON"
    end
  end

  def authenticate!
    @user = User.find_by(token: request.env['HTTP_TOKEN'])
    halt 403 unless @user
  end

  get '/' do
    movies = Movie.joins(:user_movie_ratings).distinct
    movies.to_json({:include => :user_movie_ratings})
  end

  post '/login' do
    params = @request_payload[:user]
    user = User.find_by(email: params[:email])
    if user && user.password == params[:password] #compare the hash to the string; magic
      user.generate_token!
      {token: user.token}.to_json # make sure you give hte user the token
    else
      {error: 'Invalid email and password'}.to_json
    end
  end

  post '/register' do
    params = @request_payload[:user]
    if !User.exists?(:email => params[:email])
      user = User.create(email: params[:email], password: params[:password])
      user.generate_token!
      user.save
      token = user.token
      {token: token}.to_json
    else
      {error: 'User already exists'}.to_json
    end
  end

  get '/movies/?' do
    authenticate!
    @movies = UserMovieRating.joins(:movie).where(user_movie_ratings: {user_id: @user.id})
    @movies.to_json({:include => :movie})
  end

  post '/movie/?' do
    authenticate!
    params = @request_payload[:movie]
    movie_exists = Movie.exists?(:imdbId => params[:imdbId])
    if movie_exists
      added_movie = Movie.where(:imdbId => params[:imdbId]).take
      user_movie_rating = UserMovieRating.create movie: added_movie, user: @user, rating: @request_payload[:rating], comment: @request_payload[:comment]
      user_movie_rating.save
      {status: 'SUCCESS'}.to_json
    else
      movie = Movie.create(
        title: params[:title],
        year: params[:year],
        rated: params[:rated],
        genre: params[:genre],
        imageUrl: params[:imageUrl],
        director: params[:director],
        writer: params[:writer],
        actor: params[:actor],
        plot: params[:plot],
        imdbId: params[:imdbId]
      )
      movie.save
      user_movie_rating = UserMovieRating.create movie: movie, user: @user, rating: @request_payload[:rating], comment: @request_payload[:comment]
      user_movie_rating.save
      {status: 'SUCCESS'}.to_json
    end
  end

  get '/search/?' do
    authenticate!
    title = params[:title]
    http = Net::HTTP.new(OMDBAPI_BASE_URL)
    req = Net::HTTP::Get.new("/?t=#{CGI.escape(title)}&apikey=#{KEY}")
    res = http.request(req)
    data = JSON.parse(res.body)
    MovieSearch.new(data, @user).to_json
  end

  put '/user_movie_rating/:id/?' do
    authenticate!
    payload = @request_payload[:user_movie_rating]
    if UserMovieRating.exists?(:id => params[:id])
      UserMovieRating.update(params[:id], :rating => payload[:rating], :comment => payload[:comment])
      {status: 'SUCCESS'}.to_json
    else
      {status: 'ERROR', error: 'User rating and comment does not exist'}.to_json
    end
  end

  delete '/user_movie_rating/:id' do
    authenticate!
    UserMovieRating.delete(params[:id])
    {status: 'SUCCESS'}.to_json
  end

  options "*" do
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type, Accept, X-User-Email, X-Auth-Token, token"
    response.headers["Access-Control-Allow-Origin"] = "*"
    200
  end

end

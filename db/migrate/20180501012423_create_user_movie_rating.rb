class CreateUserMovieRating < ActiveRecord::Migration[5.2]
  def change
    create_table :user_movie_ratings do |m|
      m.integer :movie_id
      m.integer :user_id
      m.integer :rating
    end
  end
end

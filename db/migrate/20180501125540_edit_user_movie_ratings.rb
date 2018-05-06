class EditUserMovieRatings < ActiveRecord::Migration[5.2]
  def change
    add_column :user_movie_ratings, :comment, :string
  end
end

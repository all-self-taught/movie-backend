class EditMovies < ActiveRecord::Migration[5.2]
  def change
    add_column :movies, :imdbId, :string
  end
end

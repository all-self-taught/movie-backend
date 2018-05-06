class CreateMovies < ActiveRecord::Migration[5.2]
  def change
    create_table :movies do |m|
      m.string :title
      m.string :year
      m.string :rated
      m.string :genre
      m.string :imageUrl
      m.string :director
      m.string :writer
      m.string :actor
      m.string :plot
    end
  end
end

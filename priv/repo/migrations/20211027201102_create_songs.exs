defmodule LiveBeats.Repo.Migrations.CreateSongs do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""

    create table(:songs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :album_artist, :string
      add :artist, :string, null: false
      add :duration, :integer, default: 0, null: false
      add :status, :integer, null: false, default: 1
      add :played_at, :utc_datetime
      add :paused_at, :utc_datetime
      add :title, :string, null: false
      add :attribution, :string
      add :mp3_url, :string, null: false
      add :mp3_filename, :string, null: false
      add :mp3_filepath, :string, null: false
      add :date_recorded, :naive_datetime
      add :date_released, :naive_datetime
      add :user_id, :binary_id
      add :genre_id, references(:genres, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create index(:songs, [:user_id])
    create index(:songs, [:genre_id])
    create index(:songs, [:status])
    create unique_index(:songs, [:user_id, :title, :artist])
  end
end

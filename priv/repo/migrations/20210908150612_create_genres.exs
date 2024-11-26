defmodule LiveBeats.Repo.Migrations.CreateGenres do
  use Ecto.Migration

  def change do
    create table(:genres, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :text, null: false
      add :slug, :text, null: false

      timestamps()
    end

    create unique_index(:genres, [:title])
    create unique_index(:genres, [:slug])
  end
end

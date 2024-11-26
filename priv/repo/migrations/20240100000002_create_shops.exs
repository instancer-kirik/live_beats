defmodule LiveBeats.Repo.Migrations.CreateShops do
  use Ecto.Migration

  def change do
    create table(:shops, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :owner_id, :binary_id, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:shops, [:owner_id])
  end
end

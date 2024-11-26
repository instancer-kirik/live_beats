defmodule LiveBeats.Shops.Shop do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "shops" do
    field :name, :string
    field :description, :string

    belongs_to :owner, Acts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(shop, attrs) do
    shop
    |> cast(attrs, [:name, :description, :owner_id])
    |> validate_required([:name, :owner_id])
  end
end

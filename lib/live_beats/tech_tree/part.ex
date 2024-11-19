defmodule LiveBeats.TechTree.Part do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tech_parts" do
    field :name, :string
    field :description, :string
    field :part_number, :string
    field :category, :string
    field :manufacturer, :string
    field :supplier, :string
    field :cost, :decimal
    field :quantity, :integer
    field :min_quantity, :integer
    field :location, :string
    field :specifications, :map
    field :search_vector, LiveBeats.Types.TsVector

    belongs_to :shop, LiveBeats.Shops.Shop
    many_to_many :items, LiveBeats.TechTree.Item, join_through: "item_parts"
    many_to_many :kits, LiveBeats.TechTree.Kit, join_through: "part_kits"

    timestamps()
  end

  def changeset(part, attrs) do
    part
    |> cast(attrs, [:name, :description, :part_number, :category, :manufacturer,
                   :supplier, :cost, :quantity, :min_quantity, :location, 
                   :specifications, :shop_id])
    |> validate_required([:name, :part_number, :category])
    |> validate_number(:quantity, greater_than_or_equal_to: 0)
    |> validate_number(:min_quantity, greater_than_or_equal_to: 0)
    |> validate_specifications()
    |> foreign_key_constraint(:shop_id)
  end

  defp validate_specifications(changeset) do
    validate_change(changeset, :specifications, fn :specifications, specs ->
      case validate_map_structure(specs) do
        :ok -> []
        {:error, reason} -> [specifications: reason]
      end
    end)
  end

  defp validate_map_structure(nil), do: :ok
  defp validate_map_structure(specs) when not is_map(specs), do: {:error, "must be a map"}
  defp validate_map_structure(_specs), do: :ok
end

defmodule LiveBeats.TechTree.Kit do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tech_kits" do
    field :name, :string
    field :description, :string
    field :kit_number, :string
    field :category, :string
    field :status, :string
    field :location, :string
    field :contents, {:array, :map}
    field :assembly_instructions, :string
    field :notes, :string
    field :search_vector, LiveBeats.Types.TsVector

    belongs_to :shop, LiveBeats.Shops.Shop
    many_to_many :items, LiveBeats.TechTree.Item, join_through: "item_kits"
    many_to_many :parts, LiveBeats.TechTree.Part, join_through: "part_kits"

    timestamps()
  end

  def changeset(kit, attrs) do
    kit
    |> cast(attrs, [:name, :description, :kit_number, :category, :status,
                   :location, :contents, :assembly_instructions, :notes, :shop_id])
    |> validate_required([:name, :kit_number, :category, :status])
    |> validate_inclusion(:status, ["complete", "incomplete", "in_use", "maintenance"])
    |> validate_contents()
    |> foreign_key_constraint(:shop_id)
  end

  defp validate_contents(changeset) do
    validate_change(changeset, :contents, fn :contents, contents ->
      case validate_contents_structure(contents) do
        :ok -> []
        {:error, reason} -> [contents: reason]
      end
    end)
  end

  defp validate_contents_structure(nil), do: :ok
  defp validate_contents_structure(contents) when not is_list(contents), do: {:error, "must be a list"}
  defp validate_contents_structure(contents) do
    if Enum.all?(contents, &valid_content_entry?/1) do
      :ok
    else
      {:error, "contains invalid content entries"}
    end
  end

  defp valid_content_entry?(%{
    "item_id" => item_id,
    "quantity" => quantity
  }) when is_integer(item_id) and is_integer(quantity) and quantity > 0, do: true
  defp valid_content_entry?(_), do: false
end

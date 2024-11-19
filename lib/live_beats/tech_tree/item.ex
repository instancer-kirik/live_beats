defmodule LiveBeats.TechTree.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tech_items" do
    field :name, :string
    field :description, :string
    field :category, :string
    field :status, :string
    field :manufacturer, :string
    field :model, :string
    field :serial_number, :string
    field :purchase_date, :date
    field :warranty_expiry, :date
    field :specifications, :map
    field :maintenance_history, {:array, :map}
    field :search_vector, LiveBeats.Types.TsVector

    belongs_to :shop, LiveBeats.Shops.Shop
    many_to_many :parts, LiveBeats.TechTree.Part, join_through: "item_parts"
    many_to_many :kits, LiveBeats.TechTree.Kit, join_through: "item_kits"
    many_to_many :documentation, LiveBeats.TechTree.Documentation, join_through: "item_documentation"

    timestamps()
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :description, :category, :status, :manufacturer, :model, 
                   :serial_number, :purchase_date, :warranty_expiry, :specifications, 
                   :maintenance_history, :shop_id])
    |> validate_required([:name, :category, :status])
    |> validate_inclusion(:status, ["active", "maintenance", "retired", "stored"])
    |> validate_specifications()
    |> validate_maintenance_history()
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

  defp validate_maintenance_history(changeset) do
    validate_change(changeset, :maintenance_history, fn :maintenance_history, history ->
      case validate_maintenance_entries(history) do
        :ok -> []
        {:error, reason} -> [maintenance_history: reason]
      end
    end)
  end

  defp validate_map_structure(nil), do: :ok
  defp validate_map_structure(specs) when not is_map(specs), do: {:error, "must be a map"}
  defp validate_map_structure(_specs), do: :ok

  defp validate_maintenance_entries(nil), do: :ok
  defp validate_maintenance_entries(history) when not is_list(history), do: {:error, "must be a list"}
  defp validate_maintenance_entries(history) do
    if Enum.all?(history, &valid_maintenance_entry?/1) do
      :ok
    else
      {:error, "contains invalid maintenance entries"}
    end
  end

  defp valid_maintenance_entry?(%{
    "date" => date,
    "type" => type,
    "description" => description
  }) when is_binary(date) and is_binary(type) and is_binary(description), do: true
  defp valid_maintenance_entry?(_), do: false
end

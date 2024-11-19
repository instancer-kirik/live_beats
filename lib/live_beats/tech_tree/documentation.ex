defmodule LiveBeats.TechTree.Documentation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tech_documentation" do
    field :title, :string
    field :description, :string
    field :content, :string
    field :doc_type, :string
    field :version, :string
    field :author, :string
    field :tags, {:array, :string}
    field :metadata, :map
    field :search_vector, LiveBeats.Types.TsVector

    many_to_many :items, LiveBeats.TechTree.Item, join_through: "item_documentation"

    timestamps()
  end

  def changeset(documentation, attrs) do
    documentation
    |> cast(attrs, [:title, :description, :content, :doc_type, :version,
                   :author, :tags, :metadata])
    |> validate_required([:title, :content, :doc_type])
    |> validate_inclusion(:doc_type, ["manual", "guide", "specification", "procedure", "note"])
    |> validate_metadata()
    |> validate_tags()
  end

  defp validate_metadata(changeset) do
    validate_change(changeset, :metadata, fn :metadata, metadata ->
      case validate_map_structure(metadata) do
        :ok -> []
        {:error, reason} -> [metadata: reason]
      end
    end)
  end

  defp validate_tags(changeset) do
    validate_change(changeset, :tags, fn :tags, tags ->
      case validate_tags_structure(tags) do
        :ok -> []
        {:error, reason} -> [tags: reason]
      end
    end)
  end

  defp validate_map_structure(nil), do: :ok
  defp validate_map_structure(metadata) when not is_map(metadata), do: {:error, "must be a map"}
  defp validate_map_structure(_metadata), do: :ok

  defp validate_tags_structure(nil), do: :ok
  defp validate_tags_structure(tags) when not is_list(tags), do: {:error, "must be a list"}
  defp validate_tags_structure(tags) do
    if Enum.all?(tags, &is_binary/1) do
      :ok
    else
      {:error, "all tags must be strings"}
    end
  end
end

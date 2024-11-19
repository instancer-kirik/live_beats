defmodule LiveBeats.TechTree do
  @moduledoc """
  The TechTree context manages technical documentation, parts, kits, and related items.
  """

  import Ecto.Query, warn: false
  alias LiveBeats.Repo
  alias LiveBeats.TechTree.{Item, Part, Kit, Documentation}
  alias LiveBeats.Shops.Shop

  # Item functions
  def list_items(opts \\ []) do
    Item
    |> apply_filters(opts[:filters] || %{})
    |> apply_sorting(opts[:sort] || [asc: :name])
    |> Repo.all()
  end

  def search_items(query, opts \\ []) do
    Item
    |> where([i], fragment("? @@ plainto_tsquery('english', ?)", i.search_vector, ^query))
    |> order_by([i], desc: fragment("ts_rank(?, plainto_tsquery('english', ?))", 
                                  i.search_vector, ^query))
    |> apply_filters(opts[:filters] || %{})
    |> Repo.all()
  end

  def get_item!(id), do: Repo.get!(Item, id)

  def create_item(attrs \\ %{}) do
    %Item{}
    |> Item.changeset(attrs)
    |> Repo.insert()
  end

  def update_item(%Item{} = item, attrs) do
    item
    |> Item.changeset(attrs)
    |> Repo.update()
  end

  def delete_item(%Item{} = item), do: Repo.delete(item)

  # Part functions
  def list_parts(opts \\ []) do
    Part
    |> apply_filters(opts[:filters] || %{})
    |> apply_sorting(opts[:sort] || [asc: :name])
    |> Repo.all()
  end

  def search_parts(query, opts \\ []) do
    Part
    |> where([p], fragment("? @@ plainto_tsquery('english', ?)", p.search_vector, ^query))
    |> order_by([p], desc: fragment("ts_rank(?, plainto_tsquery('english', ?))", 
                                  p.search_vector, ^query))
    |> apply_filters(opts[:filters] || %{})
    |> Repo.all()
  end

  def get_part!(id), do: Repo.get!(Part, id)

  def create_part(attrs \\ %{}) do
    %Part{}
    |> Part.changeset(attrs)
    |> Repo.insert()
  end

  def update_part(%Part{} = part, attrs) do
    part
    |> Part.changeset(attrs)
    |> Repo.update()
  end

  def delete_part(%Part{} = part), do: Repo.delete(part)

  # Kit functions
  def list_kits(opts \\ []) do
    Kit
    |> apply_filters(opts[:filters] || %{})
    |> apply_sorting(opts[:sort] || [asc: :name])
    |> Repo.all()
  end

  def search_kits(query, opts \\ []) do
    Kit
    |> where([k], fragment("? @@ plainto_tsquery('english', ?)", k.search_vector, ^query))
    |> order_by([k], desc: fragment("ts_rank(?, plainto_tsquery('english', ?))", 
                                  k.search_vector, ^query))
    |> apply_filters(opts[:filters] || %{})
    |> Repo.all()
  end

  def get_kit!(id), do: Repo.get!(Kit, id)

  def create_kit(attrs \\ %{}) do
    %Kit{}
    |> Kit.changeset(attrs)
    |> Repo.insert()
  end

  def update_kit(%Kit{} = kit, attrs) do
    kit
    |> Kit.changeset(attrs)
    |> Repo.update()
  end

  def delete_kit(%Kit{} = kit), do: Repo.delete(kit)

  # Documentation functions
  def list_documentation(opts \\ []) do
    Documentation
    |> apply_filters(opts[:filters] || %{})
    |> apply_sorting(opts[:sort] || [asc: :title])
    |> Repo.all()
  end

  def search_documentation(query, opts \\ []) do
    Documentation
    |> where([d], fragment("? @@ plainto_tsquery('english', ?)", d.search_vector, ^query))
    |> order_by([d], desc: fragment("ts_rank(?, plainto_tsquery('english', ?))", 
                                  d.search_vector, ^query))
    |> apply_filters(opts[:filters] || %{})
    |> Repo.all()
  end

  def get_documentation!(id), do: Repo.get!(Documentation, id)

  def create_documentation(attrs \\ %{}) do
    %Documentation{}
    |> Documentation.changeset(attrs)
    |> Repo.insert()
  end

  def update_documentation(%Documentation{} = doc, attrs) do
    doc
    |> Documentation.changeset(attrs)
    |> Repo.update()
  end

  def delete_documentation(%Documentation{} = doc), do: Repo.delete(doc)

  # Shop-specific queries
  def list_shop_items(shop_id, opts \\ []) do
    Item
    |> where([i], i.shop_id == ^shop_id)
    |> apply_filters(opts[:filters] || %{})
    |> apply_sorting(opts[:sort] || [asc: :name])
    |> Repo.all()
  end

  def list_shop_parts(shop_id, opts \\ []) do
    Part
    |> where([p], p.shop_id == ^shop_id)
    |> apply_filters(opts[:filters] || %{})
    |> apply_sorting(opts[:sort] || [asc: :name])
    |> Repo.all()
  end

  def list_shop_kits(shop_id, opts \\ []) do
    Kit
    |> where([k], k.shop_id == ^shop_id)
    |> apply_filters(opts[:filters] || %{})
    |> apply_sorting(opts[:sort] || [asc: :name])
    |> Repo.all()
  end

  def search_shop_items(shop_id, query, opts \\ []) do
    Item
    |> where([i], i.shop_id == ^shop_id)
    |> where([i], fragment("? @@ plainto_tsquery('english', ?)", i.search_vector, ^query))
    |> order_by([i], desc: fragment("ts_rank(?, plainto_tsquery('english', ?))", 
                                  i.search_vector, ^query))
    |> apply_filters(opts[:filters] || %{})
    |> Repo.all()
  end

  def search_shop_parts(shop_id, query, opts \\ []) do
    Part
    |> where([p], p.shop_id == ^shop_id)
    |> where([p], fragment("? @@ plainto_tsquery('english', ?)", p.search_vector, ^query))
    |> order_by([p], desc: fragment("ts_rank(?, plainto_tsquery('english', ?))", 
                                  p.search_vector, ^query))
    |> apply_filters(opts[:filters] || %{})
    |> Repo.all()
  end

  def search_shop_kits(shop_id, query, opts \\ []) do
    Kit
    |> where([k], k.shop_id == ^shop_id)
    |> where([k], fragment("? @@ plainto_tsquery('english', ?)", k.search_vector, ^query))
    |> order_by([k], desc: fragment("ts_rank(?, plainto_tsquery('english', ?))", 
                                  k.search_vector, ^query))
    |> apply_filters(opts[:filters] || %{})
    |> Repo.all()
  end

  def get_shop_item!(shop_id, id) do
    Item
    |> where([i], i.shop_id == ^shop_id)
    |> Repo.get!(id)
  end

  def get_shop_part!(shop_id, id) do
    Part
    |> where([p], p.shop_id == ^shop_id)
    |> Repo.get!(id)
  end

  def get_shop_kit!(shop_id, id) do
    Kit
    |> where([k], k.shop_id == ^shop_id)
    |> Repo.get!(id)
  end

  # Shop inventory management
  def check_low_stock_parts(shop_id) do
    Part
    |> where([p], p.shop_id == ^shop_id)
    |> where([p], p.quantity <= p.min_quantity)
    |> Repo.all()
  end

  def update_shop_part_quantity(shop_id, part_id, quantity_change) do
    Part
    |> where([p], p.shop_id == ^shop_id and p.id == ^part_id)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      part ->
        new_quantity = part.quantity + quantity_change
        if new_quantity >= 0 do
          update_part(part, %{quantity: new_quantity})
        else
          {:error, :insufficient_quantity}
        end
    end
  end

  # Relationship functions
  def list_related_parts(item_id) do
    Part
    |> join(:inner, [p], r in "item_parts", on: r.item_id == ^item_id and r.part_id == p.id)
    |> Repo.all()
  end

  def list_related_kits(item_id) do
    Kit
    |> join(:inner, [k], r in "item_kits", on: r.item_id == ^item_id and r.kit_id == k.id)
    |> Repo.all()
  end

  def list_related_documentation(item_id) do
    Documentation
    |> join(:inner, [d], r in "item_documentation", on: r.item_id == ^item_id and r.documentation_id == d.id)
    |> Repo.all()
  end

  # Private helper functions
  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:category, category}, query ->
        where(query, [q], q.category == ^category)
      
      {:status, status}, query ->
        where(query, [q], q.status == ^status)
      
      {:manufacturer, manufacturer}, query ->
        where(query, [q], q.manufacturer == ^manufacturer)
      
      _, query -> query
    end)
  end

  defp apply_sorting(query, sort_opts) do
    order_by(query, ^sort_opts)
  end
end

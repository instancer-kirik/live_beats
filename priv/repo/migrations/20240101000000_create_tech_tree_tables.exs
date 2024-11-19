defmodule LiveBeats.Repo.Migrations.CreateTechTreeTables do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
    execute "CREATE EXTENSION IF NOT EXISTS btree_gin"

    create table(:tech_items) do
      add :name, :string, null: false
      add :description, :text
      add :category, :string, null: false
      add :status, :string, null: false
      add :manufacturer, :string
      add :model, :string
      add :serial_number, :string
      add :purchase_date, :date
      add :warranty_expiry, :date
      add :specifications, :map
      add :maintenance_history, {:array, :map}
      add :search_vector, :tsvector
      add :shop_id, references(:shops, on_delete: :nilify_all)

      timestamps()
    end

    create table(:tech_parts) do
      add :name, :string, null: false
      add :description, :text
      add :part_number, :string, null: false
      add :category, :string, null: false
      add :manufacturer, :string
      add :supplier, :string
      add :cost, :decimal
      add :quantity, :integer, default: 0
      add :min_quantity, :integer, default: 0
      add :location, :string
      add :specifications, :map
      add :search_vector, :tsvector
      add :shop_id, references(:shops, on_delete: :nilify_all)

      timestamps()
    end

    create table(:tech_kits) do
      add :name, :string, null: false
      add :description, :text
      add :kit_number, :string, null: false
      add :category, :string, null: false
      add :status, :string, null: false
      add :location, :string
      add :contents, {:array, :map}
      add :assembly_instructions, :text
      add :notes, :text
      add :search_vector, :tsvector
      add :shop_id, references(:shops, on_delete: :nilify_all)

      timestamps()
    end

    create table(:tech_documentation) do
      add :title, :string, null: false
      add :description, :text
      add :content, :text, null: false
      add :doc_type, :string, null: false
      add :version, :string
      add :author, :string
      add :tags, {:array, :string}
      add :metadata, :map
      add :search_vector, :tsvector

      timestamps()
    end

    # Join tables
    create table(:item_parts) do
      add :item_id, references(:tech_items, on_delete: :delete_all), null: false
      add :part_id, references(:tech_parts, on_delete: :delete_all), null: false
      add :quantity, :integer, default: 1
      timestamps()
    end

    create table(:item_kits) do
      add :item_id, references(:tech_items, on_delete: :delete_all), null: false
      add :kit_id, references(:tech_kits, on_delete: :delete_all), null: false
      timestamps()
    end

    create table(:part_kits) do
      add :part_id, references(:tech_parts, on_delete: :delete_all), null: false
      add :kit_id, references(:tech_kits, on_delete: :delete_all), null: false
      add :quantity, :integer, default: 1
      timestamps()
    end

    create table(:item_documentation) do
      add :item_id, references(:tech_items, on_delete: :delete_all), null: false
      add :documentation_id, references(:tech_documentation, on_delete: :delete_all), null: false
      timestamps()
    end

    # Indexes
    create index(:tech_items, :name)
    create index(:tech_items, :category)
    create index(:tech_items, :status)
    create index(:tech_items, :search_vector, using: "GIN")

    create index(:tech_parts, :name)
    create index(:tech_parts, :part_number)
    create index(:tech_parts, :category)
    create index(:tech_parts, :search_vector, using: "GIN")

    create index(:tech_kits, :name)
    create index(:tech_kits, :kit_number)
    create index(:tech_kits, :category)
    create index(:tech_kits, :status)
    create index(:tech_kits, :search_vector, using: "GIN")

    create index(:tech_documentation, :title)
    create index(:tech_documentation, :doc_type)
    create index(:tech_documentation, :search_vector, using: "GIN")

    create unique_index(:item_parts, [:item_id, :part_id])
    create unique_index(:item_kits, [:item_id, :kit_id])
    create unique_index(:part_kits, [:part_id, :kit_id])
    create unique_index(:item_documentation, [:item_id, :documentation_id])

    # Triggers for search vector updates
    execute """
    CREATE TRIGGER tech_items_vector_update
      BEFORE INSERT OR UPDATE ON tech_items
      FOR EACH ROW
      EXECUTE FUNCTION tsvector_update_trigger(
        search_vector, 'pg_catalog.english',
        name, description, category, status, manufacturer, model, serial_number
      );
    """

    execute """
    CREATE TRIGGER tech_parts_vector_update
      BEFORE INSERT OR UPDATE ON tech_parts
      FOR EACH ROW
      EXECUTE FUNCTION tsvector_update_trigger(
        search_vector, 'pg_catalog.english',
        name, description, part_number, category, manufacturer, supplier, location
      );
    """

    execute """
    CREATE TRIGGER tech_kits_vector_update
      BEFORE INSERT OR UPDATE ON tech_kits
      FOR EACH ROW
      EXECUTE FUNCTION tsvector_update_trigger(
        search_vector, 'pg_catalog.english',
        name, description, kit_number, category, status, location, assembly_instructions, notes
      );
    """

    execute """
    CREATE TRIGGER tech_documentation_vector_update
      BEFORE INSERT OR UPDATE ON tech_documentation
      FOR EACH ROW
      EXECUTE FUNCTION tsvector_update_trigger(
        search_vector, 'pg_catalog.english',
        title, description, content, doc_type, version, author
      );
    """
  end

  def down do
    drop table(:item_documentation)
    drop table(:part_kits)
    drop table(:item_kits)
    drop table(:item_parts)
    drop table(:tech_documentation)
    drop table(:tech_kits)
    drop table(:tech_parts)
    drop table(:tech_items)

    execute "DROP EXTENSION IF EXISTS pg_trgm"
    execute "DROP EXTENSION IF EXISTS btree_gin"
  end
end

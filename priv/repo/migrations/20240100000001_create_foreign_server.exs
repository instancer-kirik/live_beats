defmodule LiveBeats.Repo.Migrations.CreateForeignServer do
  use Ecto.Migration

  def up do
    execute """
    CREATE EXTENSION IF NOT EXISTS postgres_fdw;
    """

    execute """
    CREATE SERVER acts_server
      FOREIGN DATA WRAPPER postgres_fdw
      OPTIONS (host 'localhost', port '5432', dbname 'acts_dev');
    """

    execute """
    CREATE USER MAPPING FOR CURRENT_USER
      SERVER acts_server
      OPTIONS (user 'postgres', password 'postgres');
    """

    execute """
    IMPORT FOREIGN SCHEMA public
      LIMIT TO (users)
      FROM SERVER acts_server
      INTO public;
    """
  end

  def down do
    execute """
    DROP USER MAPPING IF EXISTS FOR CURRENT_USER
      SERVER acts_server;
    """

    execute """
    DROP SERVER IF EXISTS acts_server
      CASCADE;
    """

    execute """
    DROP EXTENSION IF EXISTS postgres_fdw;
    """
  end
end

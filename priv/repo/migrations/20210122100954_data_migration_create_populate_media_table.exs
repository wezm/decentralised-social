defmodule Pleroma.Repo.Migrations.DataMigrationCreatePopulateMediaTable do
  use Ecto.Migration

  def up do
    dt = NaiveDateTime.utc_now()

    execute(
      "INSERT INTO data_migrations(name, inserted_at, updated_at) " <>
        "VALUES ('populate_media_table', '#{dt}', '#{dt}') ON CONFLICT DO NOTHING;"
    )
  end

  def down, do: :ok
end

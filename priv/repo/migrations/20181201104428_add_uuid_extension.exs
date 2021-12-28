defmodule Pleroma.Repo.Migrations.AddUUIDExtension do
  use Ecto.Migration

  def up do
    # execute("create extension if not exists \"uuid-ossp\"")
    :ok
  end

  def down, do: :ok
end

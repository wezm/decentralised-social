defmodule Pleroma.Repo.Migrations.CreateMedia do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:media) do
      add(:href, :string, null: false)
      add(:type, :string, null: false)
      add(:media_type, :string, null: false)
      add(:name, :string)
      add(:blurhash, :string)
      add(:meta, :map)
      # TODO discuss delete_all option
      add(:object_id, references(:objects, on_delete: :nothing), null: true)
      add(:user_id, references(:users, type: :uuid, on_delete: :nothing), null: false)

      timestamps()
    end
  end
end

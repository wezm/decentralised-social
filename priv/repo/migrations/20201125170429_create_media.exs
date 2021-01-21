defmodule Pleroma.Repo.Migrations.CreateMedia do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:media) do
      add(:actor, :string)
      add(:href, :string, null: false)
      add(:type, :string, null: false)
      add(:media_type, :string, null: false)
      add(:name, :string)
      add(:blurhash, :string)
      add(:meta, :map)

      add(:object_id, references(:objects, on_delete: :delete_all), null: true)

      timestamps()
    end
  end
end

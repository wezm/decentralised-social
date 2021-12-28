defmodule Pleroma.Repo.Migrations.AddUserAndHub do
  use Ecto.Migration

  def change do
    alter table(:websub_client_subscriptions) do
      add(:user_id, references(:users))
      add(:hub, :string)
    end
  end
end

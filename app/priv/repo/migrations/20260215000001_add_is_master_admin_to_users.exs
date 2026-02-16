defmodule App.Repo.Migrations.AddIsMasterAdminToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_master_admin, :boolean, default: false
    end
  end
end

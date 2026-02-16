defmodule App.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :username, :string, null: false
      add :password_hash, :string, null: false
      add :is_admin, :boolean, default: false
      add :is_approved, :boolean, default: true

      timestamps()
    end

    create unique_index(:users, [:username])
  end
end

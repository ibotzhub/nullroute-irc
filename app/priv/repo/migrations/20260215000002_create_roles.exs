defmodule App.Repo.Migrations.CreateRoles do
  use Ecto.Migration

  def change do
    create table(:roles) do
      add :name, :string, null: false
      add :color, :string, default: "#7289da"
      add :permissions, :map, default: %{}
      add :priority, :integer, default: 0
      timestamps()
    end

    create unique_index(:roles, [:name])

    create table(:user_roles) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role_id, references(:roles, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:user_roles, [:user_id, :role_id])
  end
end

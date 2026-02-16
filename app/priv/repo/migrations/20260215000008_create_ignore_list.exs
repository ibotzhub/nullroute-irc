defmodule App.Repo.Migrations.CreateIgnoreList do
  use Ecto.Migration

  def change do
    create table(:ignored_users) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :ignored_nick, :string, null: false
      add :ignored_user_id, references(:users, on_delete: :delete_all)
      timestamps()
    end

    create unique_index(:ignored_users, [:user_id, :ignored_nick])
    create index(:ignored_users, [:user_id])
  end
end

defmodule App.Repo.Migrations.CreateUserNickMapping do
  use Ecto.Migration

  def change do
    create table(:user_nick_mappings) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :irc_nick, :string, null: false
      add :active, :boolean, default: true
      timestamps()
    end

    create unique_index(:user_nick_mappings, [:irc_nick], where: "active = true")
    create index(:user_nick_mappings, [:user_id])
  end
end

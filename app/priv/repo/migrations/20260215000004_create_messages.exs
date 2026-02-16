defmodule App.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :channel, :string, null: false
      add :nick, :string, null: false
      add :content, :text, null: false
      add :message_type, :string, default: "message"  # message, action, system
      add :edited_at, :utc_datetime
      add :deleted_at, :utc_datetime
      add :pinned, :boolean, default: false
      add :pinned_by_id, references(:users, on_delete: :nilify_all)
      add :pinned_at, :utc_datetime
      timestamps()
    end

    create index(:messages, [:channel, :inserted_at])
    create index(:messages, [:user_id])
    create index(:messages, [:nick])
    create index(:messages, [:pinned])
    create index(:messages, [:deleted_at])
  end
end

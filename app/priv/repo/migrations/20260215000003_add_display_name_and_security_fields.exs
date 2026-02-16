defmodule App.Repo.Migrations.AddDisplayNameAndSecurityFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :display_name, :string
      add :avatar_url, :string
      add :bio, :text
      add :failed_login_attempts, :integer, default: 0
      add :locked_until, :utc_datetime
      add :last_login_at, :utc_datetime
      add :last_login_ip, :string
      add :unique_id, :string  # For preventing impersonation (like Discord discriminator)
    end

    create unique_index(:users, [:display_name, :unique_id])
    # username index already exists from create_users; display_name index for lookups
    create index(:users, [:display_name])
  end
end

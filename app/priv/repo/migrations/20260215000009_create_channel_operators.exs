defmodule App.Repo.Migrations.CreateChannelOperators do
  use Ecto.Migration

  def change do
    create table(:channel_operators) do
      add :channel, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :operator_type, :string, null: false  # "op", "halfop", "voice"
      timestamps()
    end

    create unique_index(:channel_operators, [:channel, :user_id])
    create index(:channel_operators, [:channel])
    create index(:channel_operators, [:user_id])
  end
end

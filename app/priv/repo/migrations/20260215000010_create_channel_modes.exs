defmodule App.Repo.Migrations.CreateChannelModes do
  use Ecto.Migration

  def change do
    create table(:channel_modes) do
      add :channel, :string, null: false
      add :modes, :text  # JSON array of mode strings like ["+n", "+t", "+m"]
      add :password, :string
      add :user_limit, :integer
      timestamps()
    end

    create unique_index(:channel_modes, [:channel])
  end
end

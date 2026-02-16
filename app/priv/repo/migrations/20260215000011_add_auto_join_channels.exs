defmodule App.Repo.Migrations.AddAutoJoinChannels do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :auto_join_channels, :string
    end
  end
end

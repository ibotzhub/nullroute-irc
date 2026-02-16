defmodule App.Repo.Migrations.AddAwayStatus do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :away, :boolean, default: false
      add :away_message, :text
    end
  end
end

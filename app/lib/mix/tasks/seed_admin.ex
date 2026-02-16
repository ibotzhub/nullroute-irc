defmodule Mix.Tasks.SeedAdmin do
  @shortdoc "Create admin user (username: admin, password: changeme123) if not exists"
  @moduledoc """
  Creates admin user without starting the full Phoenix app.
  Run: MIX_ENV=prod mix seed_admin
  """
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    # Start only Repo, not the full app
    Mix.Task.run("app.start", [])

    alias App.Repo
    alias App.Accounts.User

    unless Repo.get_by(User, username: "admin") do
      unique_id = App.Accounts.generate_unique_id()
      %User{}
      |> User.registration_changeset(%{
        username: "admin",
        password: "changeme123",
        display_name: "Admin",
        unique_id: unique_id,
        is_admin: true,
        is_master_admin: true,
        is_approved: true
      })
      |> Repo.insert!()
      IO.puts("Created admin user (username: admin, password: changeme123)")
    else
      IO.puts("Admin user already exists")
    end
  end
end

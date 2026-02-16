# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     App.Repo.insert!(%App.SomeSchema{})

alias App.Repo
alias App.Accounts.User

# Create master admin user if it doesn't exist
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
end

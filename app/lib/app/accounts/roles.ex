defmodule App.Accounts.Roles do
  @moduledoc """
  Roles context - role management
  """
  import Ecto.Query
  alias App.Repo
  alias App.Accounts.Role
  alias App.Accounts.User

  def list_roles do
    Repo.all(Role)
    |> Repo.preload(:users)
  end

  def get_role(id), do: Repo.get(Role, id)
  def get_role_by_name(name), do: Repo.get_by(Role, name: name)

  def create_role(attrs \\ %{}) do
    # Set default permissions if not provided
    attrs = Map.update(attrs, :permissions, Role.default_permissions(), fn perms ->
      perms || Role.default_permissions()
    end)

    %Role{}
    |> Role.changeset(attrs)
    |> Repo.insert()
  end

  def update_role(role, attrs) do
    role
    |> Role.changeset(attrs)
    |> Repo.update()
  end

  def delete_role(role) do
    Repo.delete(role)
  end

  def assign_role_to_user(user, role) do
    user = Repo.preload(user, :roles)
    unless role in user.roles do
      user
      |> Repo.preload(:roles)
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:roles, user.roles ++ [role])
      |> Repo.update()
    else
      {:ok, user}
    end
  end

  def remove_role_from_user(user, role) do
    user = Repo.preload(user, :roles)
    user
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:roles, List.delete(user.roles, role))
    |> Repo.update()
  end

  def get_user_roles(user) do
    user
    |> Repo.preload(:roles)
    |> Map.get(:roles, [])
  end
end

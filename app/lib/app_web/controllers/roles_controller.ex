defmodule AppWeb.RolesController do
  use AppWeb, :controller
  alias App.Accounts
  alias App.Accounts.Roles
  alias App.Accounts.Permissions

  # Require admin authentication
  plug :require_admin

  def index(conn, _params) do
    roles = Roles.list_roles()
    json(conn, %{roles: Enum.map(roles, &format_role/1)})
  end

  def create(conn, params) do
    # Check if user has permission to create roles
    user_id = get_session(conn, :user_id)
    current_user = user_id && Accounts.get_user(user_id)
    current_user = current_user && App.Repo.preload(current_user, :roles)
    if current_user && Permissions.has_permission?(current_user, "roles", "create") do
      case Roles.create_role(params) do
        {:ok, role} ->
          json(conn, %{role: format_role(role)})
        {:error, changeset} ->
          errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, value}, acc ->
              String.replace(acc, "%{#{key}}", to_string(value))
            end)
          end)
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Failed to create role", details: errors})
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Permission denied: create roles"})
    end
  end

  def update(conn, %{"id" => id} = params) do
    user_id = get_session(conn, :user_id)
    current_user = user_id && Accounts.get_user(user_id)
    current_user = current_user && App.Repo.preload(current_user, :roles)
    if current_user && Permissions.has_permission?(current_user, "roles", "modify") do
      role = Roles.get_role(id)
      if role do
        case Roles.update_role(role, params) do
          {:ok, updated_role} ->
            json(conn, %{role: format_role(updated_role)})
          {:error, changeset} ->
            errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
              Enum.reduce(opts, msg, fn {key, value}, acc ->
                String.replace(acc, "%{#{key}}", to_string(value))
              end)
            end)
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to update role", details: errors})
        end
      else
        conn
        |> put_status(:not_found)
        |> json(%{error: "Role not found"})
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Permission denied: modify roles"})
    end
  end

  def delete(conn, %{"id" => id}) do
    user_id = get_session(conn, :user_id)
    current_user = user_id && Accounts.get_user(user_id)
    current_user = current_user && App.Repo.preload(current_user, :roles)
    if current_user && Permissions.has_permission?(current_user, "roles", "delete") do
      role = Roles.get_role(id)
      if role do
        case Roles.delete_role(role) do
          {:ok, _} ->
            json(conn, %{ok: true})
          {:error, _changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to delete role"})
        end
      else
        conn
        |> put_status(:not_found)
        |> json(%{error: "Role not found"})
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Permission denied: delete roles"})
    end
  end

  def assign_role(conn, %{"user_id" => user_id, "role_id" => role_id}) do
    sess_user_id = get_session(conn, :user_id)
    current_user = sess_user_id && Accounts.get_user(sess_user_id)
    current_user = current_user && App.Repo.preload(current_user, :roles)
    if current_user && Permissions.has_permission?(current_user, "roles", "assign") do
      user = Accounts.get_user(user_id)
      role = Roles.get_role(role_id)
      if user && role do
        case Roles.assign_role_to_user(user, role) do
          {:ok, _user} ->
            json(conn, %{ok: true})
          {:error, _changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to assign role"})
        end
      else
        conn
        |> put_status(:not_found)
        |> json(%{error: "User or role not found"})
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Permission denied: assign roles"})
    end
  end

  def remove_role(conn, %{"user_id" => user_id, "role_id" => role_id}) do
    sess_user_id = get_session(conn, :user_id)
    current_user = sess_user_id && Accounts.get_user(sess_user_id)
    current_user = current_user && App.Repo.preload(current_user, :roles)
    if current_user && Permissions.has_permission?(current_user, "roles", "assign") do
      user = Accounts.get_user(user_id)
      role = Roles.get_role(role_id)
      if user && role do
        case Roles.remove_role_from_user(user, role) do
          {:ok, _user} ->
            json(conn, %{ok: true})
          {:error, _changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to remove role"})
        end
      else
        conn
        |> put_status(:not_found)
        |> json(%{error: "User or role not found"})
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Permission denied: assign roles"})
    end
  end

  defp format_role(role) do
    %{
      id: role.id,
      name: role.name,
      color: role.color,
      permissions: role.permissions || App.Accounts.Role.default_permissions(),
      priority: role.priority,
      user_count: length(role.users || [])
    }
  end

  defp require_admin(conn, _opts) do
    user_id = get_session(conn, :user_id)
    if user_id do
      user = Accounts.get_user(user_id)
      if user && (user.is_admin || user.is_master_admin) do
        conn
      else
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Admin access required"})
        |> halt()
      end
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Not authenticated"})
      |> halt()
    end
  end
end

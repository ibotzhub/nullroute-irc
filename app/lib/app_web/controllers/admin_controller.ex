defmodule AppWeb.AdminController do
  use AppWeb, :controller
  alias App.Accounts
  alias App.Accounts.Permissions

  # Require admin authentication for all actions
  plug :require_admin

  def settings(conn, _params) do
    # TODO: Load from database/config file
    json(conn, %{
      appTitle: "NullRoute IRC",
      registrationMode: "open",
      requireApproval: false,
      autoJoinChannels: ["#lobby"],
      theme: "dark"
    })
  end

  def update_settings(conn, _params) do
    # Check permission to modify server settings
    user_id = get_session(conn, :user_id)
    current_user = user_id && Accounts.get_user(user_id)
    current_user = current_user && App.Repo.preload(current_user, :roles)
    if current_user && Permissions.has_permission?(current_user, "server", "modify_settings") do
      # TODO: Save to database/config file
      # For now, just return success
      json(conn, %{ok: true})
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Permission denied: modify server settings"})
    end
  end

  def users(conn, _params) do
    users = Accounts.list_users()
    current_user = Accounts.get_user(get_session(conn, :user_id))
    
    # Master admin can see everything, regular admin sees limited info
    json(conn, %{
      users: Enum.map(users, fn u ->
        u = App.Repo.preload(u, :roles)
        base_info = %{
          id: u.id,
          username: u.username,
          is_admin: u.is_admin,
          is_master_admin: u.is_master_admin || false,
          is_approved: u.is_approved,
          theme: u.theme || "dark",
          roles: Enum.map(u.roles || [], fn r ->
            %{id: r.id, name: r.name, color: r.color}
          end)
        }
        
        # Only master admin can see all user details
        if current_user && current_user.is_master_admin do
          base_info
        else
          # Regular admin sees limited info
          Map.delete(base_info, :is_master_admin)
        end
      end)
    })
  end

  def set_admin(conn, %{"id" => user_id, "isAdmin" => is_admin}) do
    # Only master admin can assign/remove admin roles
    current_user = Accounts.get_user(get_session(conn, :user_id))
    if current_user && current_user.is_master_admin do
      # Convert boolean string to boolean if needed
      is_admin_bool = case is_admin do
        true -> true
        false -> false
        "true" -> true
        "false" -> false
        _ -> false
      end
      user = Accounts.get_user(user_id)
      if user do
        case Accounts.update_user(user, %{is_admin: is_admin_bool}) do
          {:ok, _user} ->
            json(conn, %{ok: true})
          {:error, _changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to update user"})
        end
      else
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Master admin access required to assign admin roles"})
    end
  end

  def set_master_admin(conn, %{"id" => user_id, "isMasterAdmin" => is_master_admin}) do
    # Only master admin can assign master admin role
    current_user = Accounts.get_user(get_session(conn, :user_id))
    if current_user && current_user.is_master_admin do
      is_master_admin_bool = case is_master_admin do
        true -> true
        false -> false
        "true" -> true
        "false" -> false
        _ -> false
      end
      
      user = Accounts.get_user(user_id)
      if user do
        case Accounts.update_user(user, %{is_master_admin: is_master_admin_bool}) do
          {:ok, _user} ->
            json(conn, %{ok: true})
          {:error, _changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to update user"})
        end
      else
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Master admin access required"})
    end
  end

  def approve_user(conn, %{"id" => user_id}) do
    user = Accounts.get_user(user_id)
    if user do
      case Accounts.update_user(user, %{is_approved: true}) do
        {:ok, _user} ->
          json(conn, %{ok: true})
        {:error, _changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Failed to approve user"})
      end
    else
      conn
      |> put_status(:not_found)
      |> json(%{error: "User not found"})
    end
  end

  defp require_admin(conn, _opts) do
    user_id = get_session(conn, :user_id)
    if user_id do
      user = Accounts.get_user(user_id)
      # Both master admin and regular admin can access admin endpoints
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

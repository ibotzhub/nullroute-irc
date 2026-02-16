defmodule App.Accounts.Permissions do
  @moduledoc """
  Simple permission checking system
  """

  # Check if user has a specific permission
  def has_permission?(user, category, action) when is_binary(category) and is_binary(action) do
    # Master admin has all permissions
    if user.is_master_admin do
      true
    else
      # Check user's roles for permission
      user_permissions = get_user_permissions(user)
      get_in(user_permissions, [category, action]) == true
    end
  end

  # Get all permissions for a user (merged from all their roles)
  def get_user_permissions(user) do
    # Master admin has all permissions
    if user.is_master_admin do
      all_permissions()
    else
      # Load roles if not already loaded
      user = App.Repo.preload(user, :roles)
      
      # Merge permissions from all roles (higher priority wins)
      user.roles
      |> Enum.sort_by(& &1.priority, :desc)
      |> Enum.reduce(App.Accounts.Role.default_permissions(), fn role, acc ->
        merge_permissions(acc, role.permissions || %{})
      end)
    end
  end

  # Merge two permission maps (second takes precedence)
  defp merge_permissions(base, override) do
    Map.merge(base, override, fn _key, base_val, override_val ->
      if is_map(base_val) and is_map(override_val) do
        Map.merge(base_val, override_val)
      else
        override_val
      end
    end)
  end

  # All permissions enabled (for master admin)
  defp all_permissions do
    %{
      "channels" => %{
        "create" => true,
        "delete" => true,
        "modify" => true,
        "view" => true
      },
      "users" => %{
        "kick" => true,
        "ban" => true,
        "mute" => true,
        "view" => true
      },
      "messages" => %{
        "delete" => true,
        "pin" => true,
        "moderate" => true
      },
      "server" => %{
        "modify_settings" => true,
        "view_logs" => true
      },
      "roles" => %{
        "create" => true,
        "assign" => true,
        "modify" => true,
        "delete" => true
      }
    }
  end
end

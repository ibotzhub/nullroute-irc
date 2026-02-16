defmodule AppWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: AppWeb

      import Plug.Conn
      import AppWeb.Gettext
      alias AppWeb.Router.Helpers, as: Routes
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import AppWeb.Gettext
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/app_web/templates",
        namespace: AppWeb

      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      unquote(view_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {AppWeb.Layouts, :app}

      unquote(view_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(view_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1]

      import Phoenix.HTML.Form
      import AppWeb.Gettext
      
      alias Phoenix.LiveView.JS
    end
  end

  defp view_helpers do
    quote do
      use Phoenix.HTML

      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1]
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end

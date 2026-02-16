defmodule AppWeb.PageController do
  use AppWeb, :controller

  def health(conn, _params) do
    json(conn, %{
      ok: true,
      ssl: "connected",
      message: "If you see this, HTTPS and Apache are working from your network"
    })
  end

  def index(conn, _params) do
    case File.read("priv/static/index.html") do
      {:ok, content} -> html(conn, content)
      {:error, _} -> 
        conn
        |> put_status(:not_found)
        |> text("Frontend not built. Run: cd ui && npm run build && cp -r dist/* ../app/priv/static/")
    end
  end

  def static_file(conn, %{"path" => path}) do
    # Prevent path traversal
    path_str = List.wrap(path) |> Path.join()
    if String.contains?(path_str, "..") do
      conn |> put_status(:bad_request) |> text("Invalid path")
    else
      file_path = Path.join(["priv", "static", "uploads", path_str])
      if File.exists?(file_path) do
        ext = Path.extname(file_path) |> String.trim_leading(".")
        content_type = if ext != "", do: MIME.type(ext), else: "application/octet-stream"
        conn
        |> put_resp_content_type(content_type)
        |> send_file(200, file_path)
      else
        conn
        |> put_status(:not_found)
        |> text("File not found")
      end
    end
  end
end

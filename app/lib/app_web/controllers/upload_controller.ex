defmodule AppWeb.UploadController do
  use AppWeb, :controller
  alias App.Accounts

  plug AppWeb.Plugs.RequireAuth

  def upload(conn, %{"file" => %Plug.Upload{} = upload}) do
    user_id = get_session(conn, :user_id)
    
    # Validate file type and size
    max_size = 10 * 1024 * 1024  # 10MB
    allowed_types = ~w(image/jpeg image/png image/gif image/webp application/pdf text/plain)
    file_size = File.stat!(upload.path).size

    cond do
      file_size > max_size ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "File too large. Maximum size is 10MB"})
      
      upload.content_type not in allowed_types ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "File type not allowed"})
      
      true ->
        # Generate unique filename
        ext = Path.extname(upload.filename)
        filename = "#{user_id}_#{System.system_time(:second)}_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}#{ext}"
        upload_path = Path.join(["priv", "static", "uploads", filename])
        
        # Ensure uploads directory exists
        File.mkdir_p!(Path.dirname(upload_path))
        
        # Copy file
        File.cp!(upload.path, upload_path)
        
        # Return URL
        url = "/uploads/#{filename}"
        json(conn, %{url: url, filename: upload.filename})
    end
  end

  def upload(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "No file provided"})
  end
end

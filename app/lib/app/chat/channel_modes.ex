defmodule App.Chat.ChannelModes do
  @moduledoc """
  Channel modes context
  """
  alias App.Repo
  alias App.Chat.ChannelMode

  def get_modes(channel) do
    case Repo.get_by(ChannelMode, channel: channel) do
      nil -> %ChannelMode{channel: channel, modes: "[]"}
      mode -> mode
    end
  end

  def set_modes(channel, attrs) do
    case Repo.get_by(ChannelMode, channel: channel) do
      nil ->
        %ChannelMode{channel: channel}
        |> ChannelMode.changeset(attrs)
        |> Repo.insert()
      existing ->
        existing
        |> ChannelMode.changeset(attrs)
        |> Repo.update()
    end
  end

  def add_mode(channel, mode) do
    modes_obj = get_modes(channel)
    current_modes = ChannelMode.parse_modes(modes_obj.modes || "[]")
    
    if mode not in current_modes do
      new_modes = [mode | current_modes]
      set_modes(channel, %{modes: ChannelMode.format_modes(new_modes)})
    else
      {:ok, modes_obj}
    end
  end

  def remove_mode(channel, mode) do
    modes_obj = get_modes(channel)
    current_modes = ChannelMode.parse_modes(modes_obj.modes || "[]")
    
    new_modes = List.delete(current_modes, mode)
    set_modes(channel, %{modes: ChannelMode.format_modes(new_modes)})
  end

  def has_mode?(channel, mode) do
    modes_obj = get_modes(channel)
    current_modes = ChannelMode.parse_modes(modes_obj.modes || "[]")
    mode in current_modes
  end
end

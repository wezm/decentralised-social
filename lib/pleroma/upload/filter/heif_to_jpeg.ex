# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Upload.Filter.HeifToJpeg do
  @behaviour Pleroma.Upload.Filter
  alias Pleroma.Upload

  @type conversion :: action :: String.t() | {action :: String.t(), opts :: String.t()}
  @type conversions :: conversion() | [conversion()]

  @spec filter(Pleroma.Upload.t()) :: {:ok, :atom} | {:error, String.t()}
  def filter(
        %Pleroma.Upload{name: name, path: path, tempfile: tempfile, content_type: "image/heic"} =
          upload
      ) do
    try do
      name = name |> String.replace_suffix(".heic", ".jpg")
      path = path |> String.replace_suffix(".heic", ".jpg")
      convert(tempfile)

      {:ok, :filtered, %Upload{upload | name: name, path: path, content_type: "image/jpeg"}}
    rescue
      e in ErlangError ->
        {:error, "#{__MODULE__}: #{inspect(e)}"}
    end
  end

  def filter(_), do: {:ok, :noop}

  defp convert(tempfile) do
    with_extension = tempfile <> ".heic"
    jpeg = tempfile <> ".jpg"

    File.rename!(tempfile, with_extension)

    args = [with_extension, jpeg]

    {_, 0} = System.cmd("heif-convert", args)

    File.rm!(with_extension)
    File.rename!(jpeg, tempfile)
  end
end

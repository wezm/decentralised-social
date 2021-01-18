# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Workers.AttachmentsCleanupWorker do
  import Ecto.Query

  alias Pleroma.Media
  alias Pleroma.Repo

  use Pleroma.Workers.WorkerHelper, queue: "attachments_cleanup"

  @impl Oban.Worker
  def perform(%Job{
        args: %{
          "op" => "cleanup_attachments",
          "object" => %{"data" => %{"attachment" => [_ | _] = attachments}}
        }
      }) do
    attachments
    |> Enum.map(& &1["id"])
    |> get_media()
    |> set_removable()
    |> do_clean()

    {:ok, :success}
  end

  def perform(%Job{args: %{"op" => "cleanup_attachments", "object" => _object}}), do: {:ok, :skip}

  defp do_clean(medias) do
    uploader = Pleroma.Config.get([Pleroma.Upload, :uploader])

    base_url =
      String.trim_trailing(
        Pleroma.Upload.base_url(),
        "/"
      )

    Enum.each(medias, fn media ->
      with true <- media.removable do
        media.href
        |> String.trim_leading("#{base_url}")
        |> uploader.delete_file()
      end

      Repo.delete(media)
    end)
  end

  defp get_media(ids) do
    from(m in Media,
      where: m.id in ^ids
    )
    |> Repo.all()
  end

  defp set_removable(medias) do
    Enum.map(medias, fn media ->
      from(m in Media,
        where: m.href == ^media.href,
        select: count(m.id)
      )
      |> Repo.one!()
      |> case do
        1 ->
          %Media{media | removable: true}

        _ ->
          %Media{media | removable: false}
      end
    end)
  end
end

# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.ScrobbleView do
  use Pleroma.Web, :view

  require Pleroma.Constants

  alias Pleroma.Activity
  alias Pleroma.HTML
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.AccountView

  def render(
        "show.json",
        %{
          activity: %Activity{
            id: id,
            data: %{
              "type" => "Listen",
              "actor" => actor,
              "published" => published,
              "object" => object
            }
          }
        } = opts
      ) do
    user = CommonAPI.get_user(actor)
    created_at = Utils.to_masto_date(published)

    %{
      id: id,
      account: AccountView.render("show.json", %{user: user, for: opts[:for]}),
      created_at: created_at,
      title: object["title"] |> HTML.strip_tags(),
      artist: object["artist"] |> HTML.strip_tags(),
      album: object["album"] |> HTML.strip_tags(),
      length: object["length"]
    }
  end

  def render("index.json", opts) do
    safe_render_many(opts.activities, __MODULE__, "show.json", opts)
  end
end

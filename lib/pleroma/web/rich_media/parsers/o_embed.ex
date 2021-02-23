# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.RichMedia.Parsers.OEmbed do
  def parse(html, _data) do
    with elements = [_ | _] <- get_discovery_data(html),
         oembed_url when is_binary(oembed_url) <- get_oembed_url(elements),
         {:ok, oembed_data} <- get_oembed_data(oembed_url) do
      oembed_data
    else
      _e -> %{}
    end
  end

  defp get_discovery_data(html) do
    html |> Floki.find("link[type='application/json+oembed']")
  end

  defp get_oembed_url([{"link", attributes, _children} | _]) do
    Enum.find_value(attributes, fn {k, v} -> if k == "href", do: v end)
  end

  # YouTube's oEmbed implementation is broken, requiring this hack.
  # https://github.com/oscarotero/Embed/issues/417#issuecomment-746673027
  defp get_oembed_data("http://www.youtube.com/oembed?" <> params) do
    # Use HTTPS explicitly, even though YouTube returns HTTP
    get_oembed_data("https://www.youtube.com/oembed?#{params}")
  end

  defp get_oembed_data(url) do
    with {:ok, %Tesla.Env{body: json}} <- Pleroma.Web.RichMedia.Helpers.rich_media_get(url) do
      Jason.decode(json)
    end
  end
end

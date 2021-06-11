# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Utils do
  alias Pleroma.Emoji
  alias Pleroma.Formatter
  alias Pleroma.HTML

  def filter_html_and_truncate(%{data: %{"content" => content}} = _object),
    do: do_filter_html_and_truncate(content)

  def filter_html_and_truncate(content, max_length \\ nil),
    do: do_filter_html_and_truncate(content, max_length)

  def scrub_html_and_truncate(%{data: %{"content" => content}} = _object),
    do: do_scrub_html_and_truncate(content)

  def scrub_html_and_truncate(content, max_length \\ nil),
    do: do_scrub_html_and_truncate(content, max_length)

  def user_name_string(user) do
    "#{user.name} " <>
      if user.local do
        "(@#{user.nickname}@#{Pleroma.Web.Endpoint.host()})"
      else
        "(@#{user.nickname})"
      end
  end

  @spec fetch_media_type(list(String.t()), String.t()) :: String.t() | nil
  def fetch_media_type(supported_types, media_type) do
    Enum.find(supported_types, fn support_type ->
      String.starts_with?(media_type, support_type)
    end)
  end

  defp do_filter_html_and_truncate(content, max_length \\ 200) when is_binary(content) do
    # html content comes from DB already encoded, but demojify decodes for us
    content
    |> Emoji.Formatter.demojify()
    |> HTML.filter_tags(Pleroma.HTML.Scrubber.BreaksOnly)
    |> HtmlEntities.decode()
    |> String.replace(~r/<br\s?\/?>/, "&#10;&#13;")
    |> Formatter.truncate(max_length)
  end

  defp do_scrub_html_and_truncate(content, max_length \\ 200) when is_binary(content) do
    # html content comes from DB already encoded, but demojify decodes for us
    content
    |> Emoji.Formatter.demojify()
    |> String.replace(~r/<br\s?\/?>/, " ")
    |> HTML.strip_tags()
    |> HtmlEntities.decode()
    |> Formatter.truncate(max_length)
  end
end

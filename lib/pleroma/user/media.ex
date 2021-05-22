# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.Media do
  alias Pleroma.Config

  def avatar_url(user, options \\ []) do
    case user.avatar do
      %{"url" => [%{"href" => href} | _]} ->
        href

      _ ->
        unless options[:no_default] do
          Config.get([:assets, :default_user_avatar], "#{Config.url()}/images/avi.png")
        end
    end
  end

  def banner_url(user, options \\ []) do
    case user.banner do
      %{"url" => [%{"href" => href} | _]} -> href
      _ -> !options[:no_default] && "#{Config.url()}/images/banner.png"
    end
  end
end

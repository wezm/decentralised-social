# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.InstanceView do
  use Pleroma.Web, :view

  alias Pleroma.Config
  alias Pleroma.Web.Nodeinfo.Nodeinfo

  @mastodon_api_level "2.7.2"

  def render("show.json", _) do
    instance = Config.get(:instance)

    %{
      uri: Pleroma.Web.base_url(),
      title: Keyword.get(instance, :name),
      description: Keyword.get(instance, :description),
      version: "#{@mastodon_api_level} (compatible; #{Pleroma.Application.named_version()})",
      email: Keyword.get(instance, :email),
      urls: %{
        streaming_api: Pleroma.Web.Endpoint.websocket_url()
      },
      stats: Pleroma.Stats.get_stats(),
      thumbnail: Pleroma.Web.base_url() <> Keyword.get(instance, :instance_thumbnail),
      languages: ["en"],
      registrations: Keyword.get(instance, :registrations_open),
      approval_required: Keyword.get(instance, :account_approval_required),
      # Extra (not present in Mastodon):
      max_toot_chars: Keyword.get(instance, :limit),
      poll_limits: Keyword.get(instance, :poll_limits),
      upload_limit: Keyword.get(instance, :upload_limit),
      avatar_upload_limit: Keyword.get(instance, :avatar_upload_limit),
      background_upload_limit: Keyword.get(instance, :background_upload_limit),
      banner_upload_limit: Keyword.get(instance, :banner_upload_limit),
      background_image: Pleroma.Web.base_url() <> Keyword.get(instance, :background_image),
      chat_limit: Keyword.get(instance, :chat_limit),
      description_limit: Keyword.get(instance, :description_limit),
      pleroma: %{
        metadata: %{
          account_activation_required: Keyword.get(instance, :account_activation_required),
          features: Nodeinfo.features(),
          federation: Nodeinfo.federation(),
          fields_limits: Nodeinfo.fields_limits(),
          post_formats: Config.get([:instance, :allowed_post_formats])
        },
        stats: %{mau: Pleroma.User.active_user_count()},
        vapid_public_key: Keyword.get(Pleroma.Web.Push.vapid_config(), :public_key)
      }
    }
  end
end

# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.ListenHandlingTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Activity
  alias Pleroma.Web.ActivityPub.Transmogrifier

  import Pleroma.Factory

  test "it works for incoming listens" do
    _user = insert(:user, ap_id: "http://mastodon.example.org/users/admin")

    audio_data = %{
      "type" => "Audio",
      "to" => ["https://www.w3.org/ns/activitystreams#Public"],
      "cc" => [],
      "id" => "http://mastodon.example.org/users/admin/listens/1234",
      "attributedTo" => "http://mastodon.example.org/users/admin",
      "title" => "lain radio episode 1",
      "artist" => "lain",
      "album" => "lain radio",
      "length" => 180_000
    }

    data = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "to" => ["https://www.w3.org/ns/activitystreams#Public"],
      "cc" => [],
      "type" => "Listen",
      "id" => "http://mastodon.example.org/users/admin/listens/1234/activity",
      "actor" => "http://mastodon.example.org/users/admin",
      "object" => audio_data
    }

    Tesla.Mock.mock(fn
      %{url: "http://mastodon.example.org/users/admin/listens/1234"} ->
        %Tesla.Env{
          status: 200,
          body: audio_data,
          headers: HttpRequestMock.activitypub_object_headers()
        }
    end)

    {:ok, %Activity{local: false} = activity} = Transmogrifier.handle_incoming(data)

    assert activity.data["type"] == "Listen"

    assert object = activity.data["object"]

    assert object["type"] == "Audio"
    assert object["title"] == "lain radio episode 1"
    assert object["artist"] == "lain"
    assert object["album"] == "lain radio"
    assert object["length"] == 180_000
  end
end

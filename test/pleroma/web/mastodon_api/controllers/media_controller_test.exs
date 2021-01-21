# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MediaControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Media
  alias Pleroma.Web.ActivityPub.ActivityPub

  describe "Upload media" do
    setup do: oauth_access(["write:media"])

    setup do
      image = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      [image: image]
    end

    setup do: clear_config([:media_proxy])
    setup do: clear_config([Pleroma.Upload])

    test "/api/v1/media", %{conn: conn, image: image} do
      desc = "Description of the image"

      media =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/v1/media", %{"file" => image, "description" => desc})
        |> json_response_and_validate_schema(:ok)

      assert media["type"] == "image"
      assert media["description"] == desc
      assert media["id"]

      media = Media.get_by_id(media["id"])
      assert media.actor == conn.assigns[:user].ap_id
    end

    test "/api/v2/media", %{conn: conn, user: user, image: image} do
      desc = "Description of the image"

      response =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> post("/api/v2/media", %{"file" => image, "description" => desc})
        |> json_response_and_validate_schema(202)

      assert media_id = response["id"]

      %{conn: conn} = oauth_access(["read:media"], user: user)

      media =
        conn
        |> get("/api/v1/media/#{media_id}")
        |> json_response_and_validate_schema(200)

      assert media["type"] == "image"
      assert media["description"] == desc
      assert media["id"]

      media = Media.get_by_id(media["id"])
      assert media.actor == user.ap_id
    end
  end

  describe "Update media description" do
    setup do: oauth_access(["write:media"])

    setup %{user: actor} do
      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      {:ok, %Media{} = media} =
        ActivityPub.upload(
          file,
          user: actor,
          description: "test-m"
        )

      [media: media]
    end

    test "/api/v1/media/:id good request", %{conn: conn, media: media} do
      media2 =
        conn
        |> put_req_header("content-type", "multipart/form-data")
        |> put("/api/v1/media/#{media.id}", %{"description" => "test-media"})
        |> json_response_and_validate_schema(:ok)

      assert media2["description"] == "test-media"
      assert refresh_record(media).name == "test-media"
    end
  end

  describe "Get media by id (/api/v1/media/:id)" do
    setup do: oauth_access(["read:media"])

    setup %{user: actor} do
      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      {:ok, %Media{} = media} =
        ActivityPub.upload(
          file,
          user: actor,
          description: "test-media"
        )

      [media: media]
    end

    test "it returns media object when requested by owner", %{conn: conn, media: media} do
      media2 =
        conn
        |> get("/api/v1/media/#{media.id}")
        |> json_response_and_validate_schema(:ok)

      assert media2["description"] == "test-media"
      assert media2["type"] == "image"
      assert media2["id"]
    end

    test "it returns 403 if media object requested by non-owner", %{media: media, user: user} do
      %{conn: conn, user: other_user} = oauth_access(["read:media"])

      assert media.actor == user.ap_id
      refute user.id == other_user.id

      conn
      |> get("/api/v1/media/#{media.id}")
      |> json_response(403)
    end
  end
end

# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.HTTP.Request.BuilderTest do
  use ExUnit.Case, async: true
  use Pleroma.Tests.Helpers
  alias Pleroma.Config
  alias Pleroma.HTTP.Request
  alias Pleroma.HTTP.Request.Builder

  describe "headers/2" do
    setup do: clear_config([:http, :send_user_agent])
    setup do: clear_config([:http, :user_agent])

    test "don't send pleroma user agent" do
      assert Builder.headers(%Request{}, []) == %Request{headers: []}
    end

    test "send pleroma user agent" do
      Config.put([:http, :send_user_agent], true)
      Config.put([:http, :user_agent], :default)

      assert Builder.headers(%Request{}, []) == %Request{
               headers: [{"user-agent", Pleroma.Application.user_agent()}]
             }
    end

    test "send custom user agent" do
      Config.put([:http, :send_user_agent], true)
      Config.put([:http, :user_agent], "totally-not-pleroma")

      assert Builder.headers(%Request{}, []) == %Request{
               headers: [{"user-agent", "totally-not-pleroma"}]
             }
    end
  end

  describe "add_param/4" do
    test "add file parameter" do
      %Request{
        body: %Tesla.Multipart{
          boundary: _,
          content_type_params: [],
          parts: [
            %Tesla.Multipart.Part{
              body: %File.Stream{
                line_or_bytes: 2048,
                modes: [:raw, :read_ahead, :read, :binary],
                path: "some-path/filename.png",
                raw: true
              },
              dispositions: [name: "filename.png", filename: "filename.png"],
              headers: []
            }
          ]
        }
      } = Builder.add_param(%Request{}, :file, "filename.png", "some-path/filename.png")
    end

    test "add key to body" do
      %{
        body: %Tesla.Multipart{
          boundary: _,
          content_type_params: [],
          parts: [
            %Tesla.Multipart.Part{
              body: "\"someval\"",
              dispositions: [name: "somekey"],
              headers: [{"content-type", "application/json"}]
            }
          ]
        }
      } = Builder.add_param(%{}, :body, "somekey", "someval")
    end

    test "add form parameter" do
      assert Builder.add_param(%{}, :form, "somename", "someval") == %{
               body: %{"somename" => "someval"}
             }
    end

    test "add for location" do
      assert Builder.add_param(%{}, :some_location, "somekey", "someval") == %{
               some_location: [{"somekey", "someval"}]
             }
    end
  end
end
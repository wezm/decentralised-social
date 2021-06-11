# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.UtilsTest do
  use Pleroma.DataCase, async: true
  import Pleroma.Factory
  alias Pleroma.Web.Metadata.Utils

  describe "filter_html_and_truncate/1" do
    test "it returns text without encoded HTML entities" do
      user = insert(:user)

      note =
        insert(:note, %{
          data: %{
            "actor" => user.ap_id,
            "id" => "https://pleroma.gov/objects/whatever",
            "content" => "Pleroma's really cool!"
          }
        })

      assert Utils.filter_html_and_truncate(note) == "Pleroma's really cool!"
    end

    test "it replaces <br> with compatible HTML entity (meta tags, push notifications)" do
      user = insert(:user)

      note =
        insert(:note, %{
          data: %{
            "actor" => user.ap_id,
            "id" => "https://pleroma.gov/objects/whatever",
            "content" => "First line<br>Second line"
          }
        })

      assert Utils.filter_html_and_truncate(note) ==
               "First line&#10;&#13;Second line"
    end

    test "it strips emojis" do
      user = insert(:user)

      note =
        insert(:note, %{
          data: %{
            "actor" => user.ap_id,
            "id" => "https://pleroma.gov/objects/whatever",
            "content" => "Mozilla Firefox :firefox:"
          }
        })

      assert Utils.filter_html_and_truncate(note) ==
               "Mozilla Firefox"
    end

    test "it strips HTML tags and other entities" do
      user = insert(:user)

      note =
        insert(:note, %{
          data: %{
            "actor" => user.ap_id,
            "id" => "https://pleroma.gov/objects/whatever",
            "content" => "<title>my title</title> <p>and a paragraph&#33;</p>"
          }
        })

      assert Utils.filter_html_and_truncate(note) ==
               "my title and a paragraph!"
    end
  end

  describe "scrub_html_and_truncate/2" do
    test "it returns text without encoded HTML entities" do
      assert Utils.scrub_html_and_truncate("Pleroma's really cool!") == "Pleroma's really cool!"
    end

    test "it truncates to specified chars" do
      assert Utils.scrub_html_and_truncate("Pleroma's really cool!", 10) == "Pleroma..."
    end

    test "it strips emojis" do
      assert Utils.scrub_html_and_truncate(
               "Open the door get on the floor everybody walk the dinosaur :dinosaur:"
             ) == "Open the door get on the floor everybody walk the dinosaur"
    end

    test "it strips HTML tags and other entities" do
      assert Utils.scrub_html_and_truncate("<title>my title</title> <p>and a paragraph&#33;</p>") ==
               "my title and a paragraph!"
    end
  end
end

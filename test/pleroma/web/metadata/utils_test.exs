# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.UtilsTest do
  use Pleroma.DataCase, async: true
  import Pleroma.Factory
  alias Pleroma.Web.Metadata.Utils

  describe "scrub_html_and_truncate" do
    test "it returns text without encode HTML (objects)" do
      user = insert(:user)

      note =
        insert(:note, %{
          data: %{
            "actor" => user.ap_id,
            "id" => "https://pleroma.gov/objects/whatever",
            "content" => "Pleroma's really cool!"
          }
        })

      assert Utils.scrub_html_and_truncate(note) == "Pleroma's really cool!"
    end

    test "it returns text without encode HTML (binaries)" do
      assert Utils.scrub_html_and_truncate("Pleroma's really cool!") == "Pleroma's really cool!"
    end

    test "it truncates to specified chars (binaries)" do
      assert Utils.scrub_html_and_truncate("Pleroma's really cool!", 10) == "Pleroma..."
    end
  end
end

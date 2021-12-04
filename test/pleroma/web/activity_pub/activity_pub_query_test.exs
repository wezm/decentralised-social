# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ActivityPubQueryTest do
  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub

  import Pleroma.Factory

  test "fetch_activities_query/2 indexes" do
    # Add a few accounts for good measure
    insert_list(3, :user)

    user = insert(:user)
    follower = insert(:user)

    # Create a follower
    User.follow(follower, user)

    # Same opts used by the Home timeline
    opts = %{
      type: ["Create", "Announce"],
      blocking_user: user,
      muting_user: user,
      reply_filtering_user: user,
      announce_filtering_user: user,
      user: user
    }

    # I don't fully understand this but it's what the Home timeline does
    recipients = [user.ap_id | User.following(user)]

    # Build the query
    query = ActivityPub.fetch_activities_query(recipients, opts)

    # Performs an EXPLAIN, fail if it's a sequence scan
    refute Repo.explain(:all, query) =~ "Seq Scan"
  end
end

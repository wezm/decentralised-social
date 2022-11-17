# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.UserExportController do
  use Pleroma.Web, :controller

  require Logger

  alias Pleroma.User
  alias Pleroma.Web.Plugs.OAuthScopesPlug

  plug(OAuthScopesPlug, %{scopes: ["follow", "read:follows"]} when action == :following)

  @following_accounts_header "Account address,Show boosts,Notify on new posts,Languages\n"

  def following(%{assigns: %{user: follower}} = conn, _) do
    friends = User.get_friends_nicknames(follower) |> Enum.join(",true,false,\n")

    csv_data = @following_accounts_header <> friends <> ",true,false,"

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"following_accounts.csv\"")
    |> put_root_layout(false)
    |> send_resp(200, csv_data)
  end
end

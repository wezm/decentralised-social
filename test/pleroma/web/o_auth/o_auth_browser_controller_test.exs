# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.OAuthBrowserControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

  alias Pleroma.Helpers.AuthHelper
  alias Pleroma.MFA
  alias Pleroma.MFA.TOTP
  alias Pleroma.Repo
  alias Pleroma.Web.OAuth.Authorization
  alias Pleroma.Web.OAuth.OAuthController

  @session_opts [
    store: :cookie,
    key: "_test",
    signing_salt: "cooldude"
  ]
  setup do
    clear_config([:instance, :account_activation_required])
    clear_config([:instance, :account_approval_required])
  end

  describe "in OAuth consumer mode, " do
    setup do
      [
        app: insert(:oauth_app),
        conn:
          build_conn()
          |> Plug.Session.call(Plug.Session.init(@session_opts))
          |> fetch_session()
      ]
    end

    setup do: clear_config([:auth, :oauth_consumer_strategies], ~w(twitter facebook))

    test "GET /oauth/prepare_request encodes parameters as `state` and redirects", %{
      app: app,
      conn: conn
    } do
      conn =
        get(
          conn,
          "/oauth/prepare_request",
          %{
            "provider" => "twitter",
            "authorization" => %{
              "scope" => "read follow",
              "client_id" => app.client_id,
              "redirect_uri" => OAuthController.default_redirect_uri(app),
              "state" => "a_state"
            }
          }
        )

      assert html_response(conn, 302)

      redirect_query = URI.parse(redirected_to(conn)).query
      assert %{"state" => state_param} = URI.decode_query(redirect_query)
      assert {:ok, state_components} = Jason.decode(state_param)

      expected_client_id = app.client_id
      expected_redirect_uri = app.redirect_uris

      assert %{
               "scope" => "read follow",
               "client_id" => ^expected_client_id,
               "redirect_uri" => ^expected_redirect_uri,
               "state" => "a_state"
             } = state_components
    end

    test "with user-bound registration, GET /oauth/<provider>/callback redirects to `redirect_uri` with `code`",
         %{app: app, conn: conn} do
      registration = insert(:registration)
      redirect_uri = OAuthController.default_redirect_uri(app)

      state_params = %{
        "scope" => Enum.join(app.scopes, " "),
        "client_id" => app.client_id,
        "redirect_uri" => redirect_uri,
        "state" => ""
      }

      conn =
        conn
        |> assign(:ueberauth_auth, %{provider: registration.provider, uid: registration.uid})
        |> get(
          "/oauth/twitter/callback",
          %{
            "oauth_token" => "G-5a3AAAAAAAwMH9AAABaektfSM",
            "oauth_verifier" => "QZl8vUqNvXMTKpdmUnGejJxuHG75WWWs",
            "provider" => "twitter",
            "state" => Jason.encode!(state_params)
          }
        )

      assert html_response(conn, 302)
      assert redirected_to(conn) =~ ~r/#{redirect_uri}\?code=.+/
    end

    test "with user-unbound registration, GET /oauth/<provider>/callback renders registration_details page",
         %{app: app, conn: conn} do
      user = insert(:user)

      state_params = %{
        "scope" => "read write",
        "client_id" => app.client_id,
        "redirect_uri" => OAuthController.default_redirect_uri(app),
        "state" => "a_state"
      }

      conn =
        conn
        |> assign(:ueberauth_auth, %{
          provider: "twitter",
          uid: "171799000",
          info: %{nickname: user.nickname, email: user.email, name: user.name, description: nil}
        })
        |> get(
          "/oauth/twitter/callback",
          %{
            "oauth_token" => "G-5a3AAAAAAAwMH9AAABaektfSM",
            "oauth_verifier" => "QZl8vUqNvXMTKpdmUnGejJxuHG75WWWs",
            "provider" => "twitter",
            "state" => Jason.encode!(state_params)
          }
        )

      assert response = html_response(conn, 200)
      assert response =~ ~r/name="op" type="submit" value="register"/
      assert response =~ ~r/name="op" type="submit" value="connect"/
      assert response =~ user.email
      assert response =~ user.nickname
    end

    test "on authentication error, GET /oauth/<provider>/callback redirects to `redirect_uri`", %{
      app: app,
      conn: conn
    } do
      state_params = %{
        "scope" => Enum.join(app.scopes, " "),
        "client_id" => app.client_id,
        "redirect_uri" => OAuthController.default_redirect_uri(app),
        "state" => ""
      }

      conn =
        conn
        |> assign(:ueberauth_failure, %{errors: [%{message: "(error description)"}]})
        |> get(
          "/oauth/twitter/callback",
          %{
            "oauth_token" => "G-5a3AAAAAAAwMH9AAABaektfSM",
            "oauth_verifier" => "QZl8vUqNvXMTKpdmUnGejJxuHG75WWWs",
            "provider" => "twitter",
            "state" => Jason.encode!(state_params)
          }
        )

      assert html_response(conn, 302)
      assert redirected_to(conn) == app.redirect_uris
      assert get_flash(conn, :error) == "Failed to authenticate: (error description)."
    end

    test "GET /oauth/registration_details renders registration details form", %{
      app: app,
      conn: conn
    } do
      conn =
        get(
          conn,
          "/oauth/registration_details",
          %{
            "authorization" => %{
              "scopes" => app.scopes,
              "client_id" => app.client_id,
              "redirect_uri" => OAuthController.default_redirect_uri(app),
              "state" => "a_state",
              "nickname" => nil,
              "email" => "john@doe.com"
            }
          }
        )

      assert response = html_response(conn, 200)
      assert response =~ ~r/name="op" type="submit" value="register"/
      assert response =~ ~r/name="op" type="submit" value="connect"/
    end

    test "with valid params, POST /oauth/register?op=register redirects to `redirect_uri` with `code`",
         %{
           app: app,
           conn: conn
         } do
      registration = insert(:registration, user: nil, info: %{"nickname" => nil, "email" => nil})
      redirect_uri = OAuthController.default_redirect_uri(app)

      conn =
        conn
        |> put_session(:registration_id, registration.id)
        |> post(
          "/oauth/register",
          %{
            "op" => "register",
            "authorization" => %{
              "scopes" => app.scopes,
              "client_id" => app.client_id,
              "redirect_uri" => redirect_uri,
              "state" => "a_state",
              "nickname" => "availablenick",
              "email" => "available@email.com"
            }
          }
        )

      assert html_response(conn, 302)
      assert redirected_to(conn) =~ ~r/#{redirect_uri}\?code=.+/
    end

    test "with unlisted `redirect_uri`, POST /oauth/register?op=register results in HTTP 401",
         %{
           app: app,
           conn: conn
         } do
      registration = insert(:registration, user: nil, info: %{"nickname" => nil, "email" => nil})
      unlisted_redirect_uri = "http://cross-site-request.com"

      conn =
        conn
        |> put_session(:registration_id, registration.id)
        |> post(
          "/oauth/register",
          %{
            "op" => "register",
            "authorization" => %{
              "scopes" => app.scopes,
              "client_id" => app.client_id,
              "redirect_uri" => unlisted_redirect_uri,
              "state" => "a_state",
              "nickname" => "availablenick",
              "email" => "available@email.com"
            }
          }
        )

      assert html_response(conn, 401)
    end

    test "with invalid params, POST /oauth/register?op=register renders registration_details page",
         %{
           app: app,
           conn: conn
         } do
      another_user = insert(:user)
      registration = insert(:registration, user: nil, info: %{"nickname" => nil, "email" => nil})

      params = %{
        "op" => "register",
        "authorization" => %{
          "scopes" => app.scopes,
          "client_id" => app.client_id,
          "redirect_uri" => OAuthController.default_redirect_uri(app),
          "state" => "a_state",
          "nickname" => "availablenickname",
          "email" => "available@email.com"
        }
      }

      for {bad_param, bad_param_value} <-
            [{"nickname", another_user.nickname}, {"email", another_user.email}] do
        bad_registration_attrs = %{
          "authorization" => Map.put(params["authorization"], bad_param, bad_param_value)
        }

        bad_params = Map.merge(params, bad_registration_attrs)

        conn =
          conn
          |> put_session(:registration_id, registration.id)
          |> post("/oauth/register", bad_params)

        assert html_response(conn, 403) =~ ~r/name="op" type="submit" value="register"/
        assert get_flash(conn, :error) == "Error: #{bad_param} has already been taken."
      end
    end

    test "with valid params, POST /oauth/register?op=connect redirects to `redirect_uri` with `code`",
         %{
           app: app,
           conn: conn
         } do
      user = insert(:user, password_hash: Pleroma.Password.Pbkdf2.hash_pwd_salt("testpassword"))
      registration = insert(:registration, user: nil)
      redirect_uri = OAuthController.default_redirect_uri(app)

      conn =
        conn
        |> put_session(:registration_id, registration.id)
        |> post(
          "/oauth/register",
          %{
            "op" => "connect",
            "authorization" => %{
              "scopes" => app.scopes,
              "client_id" => app.client_id,
              "redirect_uri" => redirect_uri,
              "state" => "a_state",
              "name" => user.nickname,
              "password" => "testpassword"
            }
          }
        )

      assert html_response(conn, 302)
      assert redirected_to(conn) =~ ~r/#{redirect_uri}\?code=.+/
    end

    test "with unlisted `redirect_uri`, POST /oauth/register?op=connect results in HTTP 401`",
         %{
           app: app,
           conn: conn
         } do
      user = insert(:user, password_hash: Pleroma.Password.Pbkdf2.hash_pwd_salt("testpassword"))
      registration = insert(:registration, user: nil)
      unlisted_redirect_uri = "http://cross-site-request.com"

      conn =
        conn
        |> put_session(:registration_id, registration.id)
        |> post(
          "/oauth/register",
          %{
            "op" => "connect",
            "authorization" => %{
              "scopes" => app.scopes,
              "client_id" => app.client_id,
              "redirect_uri" => unlisted_redirect_uri,
              "state" => "a_state",
              "name" => user.nickname,
              "password" => "testpassword"
            }
          }
        )

      assert html_response(conn, 401)
    end

    test "with invalid params, POST /oauth/register?op=connect renders registration_details page",
         %{
           app: app,
           conn: conn
         } do
      user = insert(:user)
      registration = insert(:registration, user: nil)

      params = %{
        "op" => "connect",
        "authorization" => %{
          "scopes" => app.scopes,
          "client_id" => app.client_id,
          "redirect_uri" => OAuthController.default_redirect_uri(app),
          "state" => "a_state",
          "name" => user.nickname,
          "password" => "wrong password"
        }
      }

      conn =
        conn
        |> put_session(:registration_id, registration.id)
        |> post("/oauth/register", params)

      assert html_response(conn, 401) =~ ~r/name="op" type="submit" value="connect"/
      assert get_flash(conn, :error) == "Invalid Username/Password"
    end
  end

  describe "POST /oauth/authorize_callback" do
    test "redirects with oauth authorization, " <>
           "granting requested app-supported scopes to both admin- and non-admin users" do
      app_scopes = ["read", "write", "admin", "secret_scope"]
      app = insert(:oauth_app, scopes: app_scopes)
      redirect_uri = OAuthController.default_redirect_uri(app)

      non_admin = insert(:user, is_admin: false)
      admin = insert(:user, is_admin: true)
      scopes_subset = ["read:subscope", "write", "admin"]

      # In case scope param is missing, expecting _all_ app-supported scopes to be granted
      for user <- [non_admin, admin],
          {requested_scopes, expected_scopes} <-
            %{scopes_subset => scopes_subset, nil: app_scopes} do
        conn =
          post(
            build_conn(),
            "/oauth/authorize_callback",
            %{
              "authorization" => %{
                "name" => user.nickname,
                "password" => "test",
                "client_id" => app.client_id,
                "redirect_uri" => redirect_uri,
                "scope" => requested_scopes,
                "state" => "statepassed"
              }
            }
          )

        target = redirected_to(conn)
        assert target =~ redirect_uri

        query = URI.parse(target).query |> URI.query_decoder() |> Map.new()

        assert %{"state" => "statepassed", "code" => code} = query
        auth = Repo.get_by(Authorization, token: code)
        assert auth
        assert auth.scopes == expected_scopes
      end
    end

    test "authorize from cookie" do
      user = insert(:user)
      app = insert(:oauth_app)
      oauth_token = insert(:oauth_token, user: user, app: app)
      redirect_uri = OAuthController.default_redirect_uri(app)

      conn =
        build_conn()
        |> Plug.Session.call(Plug.Session.init(@session_opts))
        |> fetch_session()
        |> AuthHelper.put_session_token(oauth_token.token)
        |> post(
          "/oauth/authorize_callback",
          %{
            "authorization" => %{
              "name" => user.nickname,
              "client_id" => app.client_id,
              "redirect_uri" => redirect_uri,
              "scope" => app.scopes,
              "state" => "statepassed"
            }
          }
        )

      target = redirected_to(conn)
      assert target =~ redirect_uri

      query = URI.parse(target).query |> URI.query_decoder() |> Map.new()

      assert %{"state" => "statepassed", "code" => code} = query
      auth = Repo.get_by(Authorization, token: code)
      assert auth
      assert auth.scopes == app.scopes
    end

    test "redirect to on two-factor auth page" do
      otp_secret = TOTP.generate_secret()

      user =
        insert(:user,
          multi_factor_authentication_settings: %MFA.Settings{
            enabled: true,
            totp: %MFA.Settings.TOTP{secret: otp_secret, confirmed: true}
          }
        )

      app = insert(:oauth_app, scopes: ["read", "write", "follow"])

      conn =
        build_conn()
        |> post("/oauth/authorize_callback", %{
          "authorization" => %{
            "name" => user.nickname,
            "password" => "test",
            "client_id" => app.client_id,
            "redirect_uri" => app.redirect_uris,
            "scope" => "read write",
            "state" => "statepassed"
          }
        })

      result = html_response(conn, 200)

      mfa_token = Repo.get_by(MFA.Token, user_id: user.id)
      assert result =~ app.redirect_uris
      assert result =~ "statepassed"
      assert result =~ mfa_token.token
      assert result =~ "Two-factor authentication"
    end

    test "returns 401 for wrong credentials", %{conn: conn} do
      user = insert(:user)
      app = insert(:oauth_app)
      redirect_uri = OAuthController.default_redirect_uri(app)

      result =
        conn
        |> post("/oauth/authorize_callback", %{
          "authorization" => %{
            "name" => user.nickname,
            "password" => "wrong",
            "client_id" => app.client_id,
            "redirect_uri" => redirect_uri,
            "state" => "statepassed",
            "scope" => Enum.join(app.scopes, " ")
          }
        })
        |> html_response(:unauthorized)

      # Keep the details
      assert result =~ app.client_id
      assert result =~ redirect_uri

      # Error message
      assert result =~ "Invalid Username/Password"
    end

    test "returns 401 for missing scopes" do
      user = insert(:user, is_admin: false)
      app = insert(:oauth_app, scopes: ["read", "write", "admin"])
      redirect_uri = OAuthController.default_redirect_uri(app)

      result =
        build_conn()
        |> post("/oauth/authorize_callback", %{
          "authorization" => %{
            "name" => user.nickname,
            "password" => "test",
            "client_id" => app.client_id,
            "redirect_uri" => redirect_uri,
            "state" => "statepassed",
            "scope" => ""
          }
        })
        |> html_response(:unauthorized)

      # Keep the details
      assert result =~ app.client_id
      assert result =~ redirect_uri

      # Error message
      assert result =~ "This action is outside the authorized scopes"
    end

    test "returns 401 for scopes beyond app scopes hierarchy", %{conn: conn} do
      user = insert(:user)
      app = insert(:oauth_app, scopes: ["read", "write"])
      redirect_uri = OAuthController.default_redirect_uri(app)

      result =
        conn
        |> post("/oauth/authorize_callback", %{
          "authorization" => %{
            "name" => user.nickname,
            "password" => "test",
            "client_id" => app.client_id,
            "redirect_uri" => redirect_uri,
            "state" => "statepassed",
            "scope" => "read write follow"
          }
        })
        |> html_response(:unauthorized)

      # Keep the details
      assert result =~ app.client_id
      assert result =~ redirect_uri

      # Error message
      assert result =~ "This action is outside the authorized scopes"
    end
  end
end

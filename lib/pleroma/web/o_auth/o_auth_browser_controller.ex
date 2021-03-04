# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.OAuthBrowserController do
  use Pleroma.Web, :controller

  alias Pleroma.Helpers.UriHelper
  alias Pleroma.Maps
  alias Pleroma.MFA
  alias Pleroma.Registration
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.Auth.Authenticator
  alias Pleroma.Web.OAuth.Authorization
  alias Pleroma.Web.OAuth.OAuthController
  alias Pleroma.Web.OAuth.MFAController
  alias Pleroma.Web.OAuth.OAuthView
  alias Pleroma.Web.OAuth.Scopes
  alias Pleroma.Web.Plugs.RateLimiter

  require Logger

  if Pleroma.Config.oauth_consumer_enabled?(), do: plug(Ueberauth)

  plug(:fetch_session)
  plug(:fetch_flash)

  plug(:skip_plug, [
    Pleroma.Web.Plugs.OAuthScopesPlug,
    Pleroma.Web.Plugs.EnsurePublicOrAuthenticatedPlug
  ])

  plug(RateLimiter, name: :authentication)

  action_fallback(Pleroma.Web.OAuth.FallbackController)

  @oob_token_redirect_uri "urn:ietf:wg:oauth:2.0:oob"

  def authorize_callback(_, _, opts \\ [])

  def authorize_callback(%Plug.Conn{assigns: %{user: %User{} = user}} = conn, params, []) do
    authorize_callback(conn, params, user: user)
  end

  def authorize_callback(%Plug.Conn{} = conn, %{"authorization" => _} = params, opts) do
    with {:ok, auth, user} <- OAuthController.do_create_authorization(conn, params, opts[:user]),
         {:mfa_required, _, _, false} <- {:mfa_required, user, auth, MFA.require?(user)} do
      after_create_authorization(conn, auth, params)
    else
      error ->
        handle_create_authorization_error(conn, error, params)
    end
  end

  def after_create_authorization(%Plug.Conn{} = conn, %Authorization{} = auth, %{
        "authorization" => %{"redirect_uri" => @oob_token_redirect_uri}
      }) do
    # Enforcing the view to reuse the template when calling from other controllers
    conn
    |> put_view(OAuthView)
    |> render("oob_authorization_created.html", %{auth: auth})
  end

  def after_create_authorization(%Plug.Conn{} = conn, %Authorization{} = auth, %{
        "authorization" => %{"redirect_uri" => redirect_uri} = auth_attrs
      }) do
    app = Repo.preload(auth, :app).app

    # An extra safety measure before we redirect (also done in `do_create_authorization/2`)
    if redirect_uri in String.split(app.redirect_uris) do
      redirect_uri = OAuthController.redirect_uri(conn, redirect_uri)
      url_params = %{code: auth.token}
      url_params = Maps.put_if_present(url_params, :state, auth_attrs["state"])
      url = UriHelper.modify_uri_params(redirect_uri, url_params)
      redirect(conn, external: url)
    else
      conn
      |> put_flash(:error, dgettext("errors", "Unlisted redirect_uri."))
      |> redirect(external: OAuthController.redirect_uri(conn, redirect_uri))
    end
  end

  defp handle_create_authorization_error(
         %Plug.Conn{} = conn,
         {:error, scopes_issue},
         %{"authorization" => _} = params
       )
       when scopes_issue in [:unsupported_scopes, :missing_scopes] do
    # Per https://github.com/tootsuite/mastodon/blob/
    #   51e154f5e87968d6bb115e053689767ab33e80cd/app/controllers/api/base_controller.rb#L39
    conn
    |> put_flash(:error, dgettext("errors", "This action is outside the authorized scopes"))
    |> put_status(:unauthorized)
    |> OAuthController.authorize(params)
  end

  defp handle_create_authorization_error(
         %Plug.Conn{} = conn,
         {:account_status, :confirmation_pending},
         %{"authorization" => _} = params
       ) do
    conn
    |> put_flash(:error, dgettext("errors", "Your login is missing a confirmed e-mail address"))
    |> put_status(:forbidden)
    |> OAuthController.authorize(params)
  end

  defp handle_create_authorization_error(
         %Plug.Conn{} = conn,
         {:mfa_required, user, auth, _},
         params
       ) do
    {:ok, token} = MFA.Token.create(user, auth)

    data = %{
      "mfa_token" => token.token,
      "redirect_uri" => params["authorization"]["redirect_uri"],
      "state" => params["authorization"]["state"]
    }

    MFAController.show(conn, data)
  end

  defp handle_create_authorization_error(
         %Plug.Conn{} = conn,
         {:account_status, :password_reset_pending},
         %{"authorization" => _} = params
       ) do
    conn
    |> put_flash(:error, dgettext("errors", "Password reset is required"))
    |> put_status(:forbidden)
    |> OAuthController.authorize(params)
  end

  defp handle_create_authorization_error(
         %Plug.Conn{} = conn,
         {:account_status, :deactivated},
         %{"authorization" => _} = params
       ) do
    conn
    |> put_flash(:error, dgettext("errors", "Your account is currently disabled"))
    |> put_status(:forbidden)
    |> OAuthController.authorize(params)
  end

  defp handle_create_authorization_error(%Plug.Conn{} = conn, error, %{"authorization" => _}) do
    Authenticator.handle_error(conn, error)
  end

  @doc "Prepares OAuth request to provider for Ueberauth"
  def prepare_request(%Plug.Conn{} = conn, %{
        "provider" => provider,
        "authorization" => auth_attrs
      }) do
    scope =
      auth_attrs
      |> Scopes.fetch_scopes([])
      |> Scopes.to_string()

    state =
      auth_attrs
      |> Map.delete("scopes")
      |> Map.put("scope", scope)
      |> Jason.encode!()

    params =
      auth_attrs
      |> Map.drop(~w(scope scopes client_id redirect_uri))
      |> Map.put("state", state)

    # Handing the request to Ueberauth
    redirect(conn, to: o_auth_browser_path(conn, :provider_request, provider, params))
  end

  def provider_request(%Plug.Conn{} = conn, params) do
    message =
      if params["provider"] do
        dgettext("errors", "Unsupported OAuth provider: %{provider}.",
          provider: params["provider"]
        )
      else
        dgettext("errors", "Bad OAuth request.")
      end

    conn
    |> put_flash(:error, message)
    |> redirect(to: "/")
  end

  def provider_callback(%Plug.Conn{assigns: %{ueberauth_failure: failure}} = conn, params) do
    params = callback_params(params)
    messages = for e <- Map.get(failure, :errors, []), do: e.message
    message = Enum.join(messages, "; ")

    conn
    |> put_flash(
      :error,
      dgettext("errors", "Failed to authenticate: %{message}.", message: message)
    )
    |> redirect(external: OAuthController.redirect_uri(conn, params["redirect_uri"]))
  end

  def provider_callback(%Plug.Conn{} = conn, params) do
    params = callback_params(params)

    with {:ok, registration} <- Authenticator.get_registration(conn) do
      auth_attrs = Map.take(params, ~w(client_id redirect_uri scope scopes state))

      case Repo.get_assoc(registration, :user) do
        {:ok, user} ->
          authorize_callback(conn, %{"authorization" => auth_attrs}, user: user)

        _ ->
          registration_params =
            Map.merge(auth_attrs, %{
              "nickname" => Registration.nickname(registration),
              "email" => Registration.email(registration)
            })

          conn
          |> put_session_registration_id(registration.id)
          |> registration_details(%{authorization: registration_params})
      end
    else
      error ->
        Logger.debug(inspect(["OAUTH_ERROR", error, conn.assigns]))

        conn
        |> put_flash(:error, dgettext("errors", "Failed to set up user account."))
        |> redirect(external: OAuthController.redirect_uri(conn, params["redirect_uri"]))
    end
  end

  defp callback_params(%{"state" => state} = params) do
    Map.merge(params, Jason.decode!(state))
  end

  def registration_details(%Plug.Conn{} = conn, %{"authorization" => auth_attrs}) do
    render(conn, "register.html", %{
      client_id: auth_attrs["client_id"],
      redirect_uri: auth_attrs["redirect_uri"],
      state: auth_attrs["state"],
      scopes: Scopes.fetch_scopes(auth_attrs, []),
      nickname: auth_attrs["nickname"],
      email: auth_attrs["email"]
    })
  end

  def register(%Plug.Conn{} = conn, %{"authorization" => _, "op" => "connect"} = params) do
    with registration_id when not is_nil(registration_id) <- get_session_registration_id(conn),
         %Registration{} = registration <- Repo.get(Registration, registration_id),
         {_, {:ok, auth, _user}} <-
           {:create_authorization, OAuthController.do_create_authorization(conn, params)},
         %User{} = user <- Repo.preload(auth, :user).user,
         {:ok, _updated_registration} <- Registration.bind_to_user(registration, user) do
      conn
      |> put_session_registration_id(nil)
      |> after_create_authorization(auth, params)
    else
      {:create_authorization, error} ->
        {:register, handle_create_authorization_error(conn, error, params)}

      _ ->
        {:register, :generic_error}
    end
  end

  def register(%Plug.Conn{} = conn, %{"authorization" => _, "op" => "register"} = params) do
    with registration_id when not is_nil(registration_id) <- get_session_registration_id(conn),
         %Registration{} = registration <- Repo.get(Registration, registration_id),
         {:ok, user} <- Authenticator.create_from_registration(conn, registration) do
      conn
      |> put_session_registration_id(nil)
      |> authorize_callback(
        params,
        user: user
      )
    else
      {:error, changeset} ->
        message =
          Enum.map(changeset.errors, fn {field, {error, _}} ->
            "#{field} #{error}"
          end)
          |> Enum.join("; ")

        message =
          String.replace(
            message,
            "ap_id has already been taken",
            "nickname has already been taken"
          )

        conn
        |> put_status(:forbidden)
        |> put_flash(:error, "Error: #{message}.")
        |> registration_details(params)

      _ ->
        {:register, :generic_error}
    end
  end

  defp get_session_registration_id(%Plug.Conn{} = conn), do: get_session(conn, :registration_id)

  defp put_session_registration_id(%Plug.Conn{} = conn, registration_id),
    do: put_session(conn, :registration_id, registration_id)
end

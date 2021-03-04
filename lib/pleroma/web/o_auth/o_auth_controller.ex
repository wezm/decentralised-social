# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.OAuthController do
  use Pleroma.Web, :controller

  alias Pleroma.Helpers.AuthHelper
  alias Pleroma.Helpers.UriHelper
  alias Pleroma.MFA
  alias Pleroma.Maps
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.Auth.Authenticator
  alias Pleroma.Web.ControllerHelper
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Authorization
  alias Pleroma.Web.OAuth.MFAView
  alias Pleroma.Web.OAuth.OAuthView
  alias Pleroma.Web.OAuth.Scopes
  alias Pleroma.Web.OAuth.Token
  alias Pleroma.Web.OAuth.Token.Strategy.RefreshToken
  alias Pleroma.Web.OAuth.Token.Strategy.Revoke, as: RevokeToken
  alias Pleroma.Web.Plugs.RateLimiter

  if Pleroma.Config.oauth_consumer_enabled?(), do: plug(Ueberauth)

  plug(Pleroma.Web.ApiSpec.CastAndValidate)

  plug(:fetch_session)
  plug(:fetch_flash)

  plug(:skip_plug, [
    Pleroma.Web.Plugs.OAuthScopesPlug,
    Pleroma.Web.Plugs.EnsurePublicOrAuthenticatedPlug
  ])

  plug(RateLimiter, name: :authentication)

  action_fallback(Pleroma.Web.OAuth.FallbackController)

  @oob_token_redirect_uri "urn:ietf:wg:oauth:2.0:oob"

  defdelegate open_api_operation(action), to: Pleroma.Web.ApiSpec.OAuthOperation

  # Note: this definition is only called from error-handling methods with `conn.params` as 2nd arg
  def authorize(%Plug.Conn{} = conn, %{authorization: _} = params) do
    {auth_attrs, params} = Map.pop(params, :authorization)
    authorize(conn, Map.merge(params, auth_attrs))
  end

  def authorize(%Plug.Conn{assigns: %{token: %Token{}}} = conn, %{force_login: _} = params) do
    if ControllerHelper.truthy_param?(params[:force_login]) do
      do_authorize(conn, params)
    else
      handle_existing_authorization(conn, params)
    end
  end

  # Note: the token is set in oauth_plug, but the token and client do not always go together.
  # For example, MastodonFE's token is set if user requests with another client,
  # after user already authorized to MastodonFE.
  # So we have to check client and token.
  def authorize(
        %Plug.Conn{assigns: %{token: %Token{} = token}} = conn,
        %{client_id: client_id} = params
      ) do
    with %Token{} = t <- Repo.get_by(Token, token: token.token) |> Repo.preload(:app),
         ^client_id <- t.app.client_id do
      handle_existing_authorization(conn, params)
    else
      _ -> do_authorize(conn, params)
    end
  end

  def authorize(%Plug.Conn{} = conn, params), do: do_authorize(conn, params)

  defp do_authorize(%Plug.Conn{} = conn, params) do
    app = Repo.get_by(App, client_id: params["client_id"])
    available_scopes = (app && app.scopes) || []
    scopes = Scopes.fetch_scopes(params, available_scopes)

    user =
      with %{assigns: %{user: %User{} = user}} <- conn do
        user
      else
        _ -> nil
      end

    scopes =
      if scopes == [] do
        available_scopes
      else
        scopes
      end

    # Note: `params` might differ from `conn.params`; use `@params` not `@conn.params` in template
    render(conn, Authenticator.auth_template(), %{
      user: user,
      app: app && Map.delete(app, :client_secret),
      response_type: params["response_type"],
      client_id: params["client_id"],
      available_scopes: available_scopes,
      scopes: scopes,
      redirect_uri: params["redirect_uri"],
      state: params["state"],
      params: params
    })
  end

  defp handle_existing_authorization(
         %Plug.Conn{assigns: %{token: %Token{} = token}} = conn,
         %{"redirect_uri" => @oob_token_redirect_uri}
       ) do
    render(conn, "oob_token_exists.html", %{token: token})
  end

  defp handle_existing_authorization(
         %Plug.Conn{assigns: %{token: %Token{} = token}} = conn,
         %{} = params
       ) do
    app = Repo.preload(token, :app).app

    redirect_uri =
      if is_binary(params["redirect_uri"]) do
        params["redirect_uri"]
      else
        default_redirect_uri(app)
      end

    if redirect_uri in String.split(app.redirect_uris) do
      redirect_uri = redirect_uri(conn, redirect_uri)
      url_params = %{access_token: token.token}
      url_params = Maps.put_if_present(url_params, :state, params["state"])
      url = UriHelper.modify_uri_params(redirect_uri, url_params)
      redirect(conn, external: url)
    else
      conn
      |> put_flash(:error, dgettext("errors", "Unlisted redirect_uri."))
      |> redirect(external: redirect_uri(conn, redirect_uri))
    end
  end

  @doc "Renew access_token with refresh_token"
  def token_exchange(
        %Plug.Conn{} = conn,
        %{grant_type: "refresh_token", refresh_token: token} = _params
      ) do
    with {:ok, app} <- Token.Utils.fetch_app(conn),
         {:ok, %{user: user} = token} <- Token.get_by_refresh_token(app, token),
         {:ok, token} <- RefreshToken.grant(token) do
      after_token_exchange(conn, %{user: user, token: token})
    else
      _error -> render_invalid_credentials_error(conn)
    end
  end

  def token_exchange(%Plug.Conn{} = conn, %{grant_type: "authorization_code"} = params) do
    with {:ok, app} <- Token.Utils.fetch_app(conn),
         fixed_token = Token.Utils.fix_padding(params[:code]),
         {:ok, auth} <- Authorization.get_by_token(app, fixed_token),
         %User{} = user <- User.get_cached_by_id(auth.user_id),
         {:ok, token} <- Token.exchange_token(app, auth) do
      after_token_exchange(conn, %{user: user, token: token})
    else
      error ->
        handle_token_exchange_error(conn, error)
    end
  end

  def token_exchange(
        %Plug.Conn{} = conn,
        %{grant_type: "password"} = params
      ) do
    with {:ok, %User{} = user} <- Authenticator.get_user(conn),
         {:ok, app} <- Token.Utils.fetch_app(conn),
         requested_scopes <- Scopes.fetch_scopes(params, app.scopes),
         {:ok, token} <- login(user, app, requested_scopes) do
      after_token_exchange(conn, %{user: user, token: token})
    else
      error ->
        handle_token_exchange_error(conn, error)
    end
  end

  def token_exchange(
        %Plug.Conn{} = conn,
        %{grant_type: "password", name: name, password: _password} = params
      ) do
    params =
      params
      |> Map.delete("name")
      |> Map.put("username", name)

    token_exchange(conn, params)
  end

  def token_exchange(%Plug.Conn{} = conn, %{grant_type: "client_credentials"} = _params) do
    with {:ok, app} <- Token.Utils.fetch_app(conn),
         {:ok, auth} <- Authorization.create_authorization(app, %User{}),
         {:ok, token} <- Token.exchange_token(app, auth) do
      after_token_exchange(conn, %{token: token})
    else
      _error ->
        handle_token_exchange_error(conn, :invalid_credentails)
    end
  end

  # Bad request
  def token_exchange(%Plug.Conn{} = _conn, _params), do: {:error, :bad_request}

  # Note: intended to be a private function but opened for AccountController that logs in on signup
  @doc "If checks pass, creates authorization and token for given user, app and requested scopes."
  def login(%User{} = user, %App{} = app, requested_scopes) when is_list(requested_scopes) do
    with {:ok, auth} <- do_create_authorization(user, app, requested_scopes),
         {:mfa_required, _, _, false} <- {:mfa_required, user, auth, MFA.require?(user)},
         {:ok, token} <- Token.exchange_token(app, auth) do
      {:ok, token}
    end
  end

  def do_create_authorization(conn, auth_attrs, user \\ nil)

  def do_create_authorization(
        %Plug.Conn{} = conn,
        %{
          "authorization" =>
            %{
              "client_id" => client_id,
              "redirect_uri" => redirect_uri
            } = auth_attrs
        },
        user
      ) do
    with {_, {:ok, %User{} = user}} <-
           {:get_user, (user && {:ok, user}) || Authenticator.get_user(conn)},
         %App{} = app <- Repo.get_by(App, client_id: client_id),
         true <- redirect_uri in String.split(app.redirect_uris),
         requested_scopes <- Scopes.fetch_scopes(auth_attrs, app.scopes),
         {:ok, auth} <- do_create_authorization(user, app, requested_scopes) do
      {:ok, auth, user}
    end
  end

  def do_create_authorization(%User{} = user, %App{} = app, requested_scopes)
      when is_list(requested_scopes) do
    with {:account_status, :active} <- {:account_status, User.account_status(user)},
         {:ok, scopes} <- validate_scopes(app, requested_scopes),
         {:ok, auth} <- Authorization.create_authorization(app, user, scopes) do
      {:ok, auth}
    end
  end

  def after_token_exchange(%Plug.Conn{} = conn, %{token: token} = view_params) do
    conn
    |> AuthHelper.put_session_token(token.token)
    |> json(OAuthView.render("token.json", view_params))
  end

  defp handle_token_exchange_error(%Plug.Conn{} = conn, {:mfa_required, user, auth, _}) do
    conn
    |> put_status(:forbidden)
    |> json(build_and_response_mfa_token(user, auth))
  end

  defp handle_token_exchange_error(%Plug.Conn{} = conn, {:account_status, :deactivated}) do
    render_error(
      conn,
      :forbidden,
      "Your account is currently disabled",
      %{},
      "account_is_disabled"
    )
  end

  defp handle_token_exchange_error(
         %Plug.Conn{} = conn,
         {:account_status, :password_reset_pending}
       ) do
    render_error(
      conn,
      :forbidden,
      "Password reset is required",
      %{},
      "password_reset_required"
    )
  end

  defp handle_token_exchange_error(%Plug.Conn{} = conn, {:account_status, :confirmation_pending}) do
    render_error(
      conn,
      :forbidden,
      "Your login is missing a confirmed e-mail address",
      %{},
      "missing_confirmed_email"
    )
  end

  defp handle_token_exchange_error(%Plug.Conn{} = conn, {:account_status, :approval_pending}) do
    render_error(
      conn,
      :forbidden,
      "Your account is awaiting approval.",
      %{},
      "awaiting_approval"
    )
  end

  defp handle_token_exchange_error(%Plug.Conn{} = conn, _error) do
    render_invalid_credentials_error(conn)
  end

  defp render_invalid_credentials_error(conn) do
    render_error(conn, :bad_request, "Invalid credentials")
  end

  defp build_and_response_mfa_token(user, auth) do
    with {:ok, token} <- MFA.Token.create(user, auth) do
      MFAView.render("mfa_response.json", %{token: token, user: user})
    end
  end

  def token_revoke(%Plug.Conn{} = conn, %{token: token}) do
    with {:ok, %Token{} = oauth_token} <- Token.get_by_token(token),
         {:ok, oauth_token} <- RevokeToken.revoke(oauth_token) do
      conn =
        with session_token = AuthHelper.get_session_token(conn),
             %Token{token: ^session_token} <- oauth_token do
          AuthHelper.delete_session_token(conn)
        else
          _ -> conn
        end

      json(conn, %{})
    else
      _error ->
        # RFC 7009: invalid tokens [in the request] do not cause an error response
        json(conn, %{})
    end
  end

  def token_revoke(%Plug.Conn{} = _conn, _params), do: {:error, :bad_request}

  # Special case: Local MastodonFE
  def redirect_uri(%Plug.Conn{} = conn, "."), do: auth_url(conn, :login)

  def redirect_uri(%Plug.Conn{}, redirect_uri), do: redirect_uri

  @spec validate_scopes(App.t(), map() | list()) ::
          {:ok, list()} | {:error, :missing_scopes | :unsupported_scopes}
  defp validate_scopes(%App{} = app, params) when is_map(params) do
    requested_scopes = Scopes.fetch_scopes(params, app.scopes)
    validate_scopes(app, requested_scopes)
  end

  defp validate_scopes(%App{} = app, requested_scopes) when is_list(requested_scopes) do
    Scopes.validate(requested_scopes, app.scopes)
  end

  def default_redirect_uri(%App{} = app) do
    app.redirect_uris
    |> String.split()
    |> Enum.at(0)
  end
end

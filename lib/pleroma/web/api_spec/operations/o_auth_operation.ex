# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.OAuthOperation do
  alias OpenApiSpex.Operation
  alias OpenApiSpex.Schema
  alias Pleroma.Web.ApiSpec.Schemas.ApiError

  def open_api_operation(action) do
    operation = String.to_existing_atom("#{action}_operation")
    apply(__MODULE__, operation, [])
  end

  defp client_id_parameter(opts) do
    Operation.parameter(
      :client_id,
      :query,
      :string,
      "Client ID, obtained during app registration",
      opts
    )
  end

  defp client_secret_parameter(opts) do
    Operation.parameter(
      :client_secret,
      :query,
      :string,
      "Client secret, obtained during app registration",
      opts
    )
  end

  defp redirect_uri_parameter(opts) do
    Operation.parameter(
      :redirect_uri,
      :query,
      :string,
      "Set a URI to redirect the user to. If this parameter is set to `urn:ietf:wg:oauth:2.0:oob` then the token will be shown instead. Must match one of the redirect URIs declared during app registration.",
      opts
    )
  end

  defp scope_parameter(opts) do
    Operation.parameter(
      :scope,
      :query,
      :string,
      "List of requested OAuth scopes, separated by spaces. Must be a subset of scopes declared during app registration. If not provided, defaults to `read`.",
      opts
    )
  end

  def token_exchange_operation do
    %Operation{
      tags: ["OAuth"],
      summary: "Access Token Request",
      operationId: "OAuthController.token_exchange",
      parameters: [
        # code is required when grant_type == "authorization_code"
        # Mastodon requires `redirect_uri`, we don't
        client_id_parameter(required: true),
        client_secret_parameter(required: true),
        redirect_uri_parameter([]),
        scope_parameter([]),
        Operation.parameter(
          :code,
          :query,
          :string,
          "A user authorization code, obtained via /oauth/authorize"
        ),
        Operation.parameter(
          :grant_type,
          :query,
          :string,
          "Set equal to `authorization_code` if `code` is provided in order to gain user-level access. Set equal to `password` if `username` and `password` are provided. Otherwise, set equal to `client_credentials` to obtain app-level access only.",
          required: true
        ),
        Operation.parameter(
          :username,
          :query,
          :string,
          "User's username, used with `grant_type=password`"
        ),
        Operation.parameter(
          :password,
          :query,
          :string,
          "User's password, used with `grant_type=password`"
        )
      ],
      responses: %{
        200 =>
          Operation.response("Success", "application/json", %Schema{
            type: :object,
            properties: %{status: %Schema{type: :string, example: "success"}}
          }),
        400 => Operation.response("Error", "application/json", ApiError),
        403 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def token_revoke_operation do
    %Operation{
      tags: ["OAuth"],
      summary: "Revokes token",
      operationId: "OAuthController.token_revoke",
      parameters: [],
      responses: %{
        200 =>
          Operation.response("Success", "application/json", %Schema{
            type: :object,
            properties: %{status: %Schema{type: :string, example: "success"}}
          }),
        400 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def registration_details_operation do
    %Operation{
      tags: ["OAuth"],
      summary: "Register",
      operationId: "OAuthController.registration_details",
      parameters: [],
      responses: %{
        200 =>
          Operation.response("Success", "application/json", %Schema{
            type: :object,
            properties: %{status: %Schema{type: :string, example: "success"}}
          }),
        400 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def authorize_operation do
    %Operation{
      tags: ["OAuth"],
      summary: "OAuth callback",
      operationId: "OAuthController.authorize",
      parameters: [
        client_id_parameter(required: true),
        client_secret_parameter([]),
        Operation.parameter(
          :response_type,
          :query,
          :string,
          "Note: `code` is the only value supported (MastodonAPI and OAuth 2.1)",
          required: true
        ),
        redirect_uri_parameter([]),
        scope_parameter([]),
        Operation.parameter(
          :state,
          :query,
          :string,
          "An opaque value used by the client to maintain state between the request and callback.  The authorization server includes this value when redirecting the user-agent back to the client."
        )
      ],
      responses: %{
        200 =>
          Operation.response("Success", "application/json", %Schema{
            type: :object,
            properties: %{status: %Schema{type: :string, example: "success"}}
          }),
        400 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def prepare_request_operation do
    %Operation{
      tags: ["OAuth"],
      summary: "Prepare OAuth request for third-party auth providers",
      operationId: "OAuthController.prepare_request",
      parameters: [],
      responses: %{
        302 =>
          Operation.response("Success", "text/html", %Schema{
            type: :object,
            properties: %{status: %Schema{type: :string, example: "success"}}
          }),
        400 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  # The following operations should be moved to another controller, they aren't meant to be into OpenAPI

  def request_operation do
    %Operation{
      tags: ["OAuth"],
      summary: "",
      operationId: "OAuthController.request",
      parameters: [],
      responses: %{
        200 =>
          Operation.response("Success", "application/json", %Schema{
            type: :object,
            properties: %{status: %Schema{type: :string, example: "success"}}
          }),
        400 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def register_operation do
    %Operation{
      tags: ["OAuth"],
      summary: "",
      operationId: "OAuthController.register",
      parameters: [],
      responses: %{
        200 =>
          Operation.response("Success", "application/json", %Schema{
            type: :object,
            properties: %{status: %Schema{type: :string, example: "success"}}
          }),
        400 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end

  def callback_operation do
    %Operation{
      tags: ["OAuth"],
      summary: "",
      operationId: "OAuthController.callback",
      parameters: [],
      responses: %{
        200 =>
          Operation.response("Success", "application/json", %Schema{
            type: :object,
            properties: %{status: %Schema{type: :string, example: "success"}}
          }),
        400 => Operation.response("Error", "application/json", ApiError)
      }
    }
  end
end

# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ReverseProxyTest do
  use Pleroma.Web.ConnCase
  import ExUnit.CaptureLog
  import Mox

  alias Pleroma.ReverseProxy
  alias Plug.Conn

  describe "reverse proxy" do
    test "do not track successful request", %{conn: conn} do
      url = "/success"

      Tesla.Mock.mock(fn %{url: ^url} ->
        %Tesla.Env{
          status: 200,
          body: ""
        }
      end)

      conn = ReverseProxy.call(conn, url)

      assert conn.status == 200
      assert Cachex.get(:failed_proxy_url_cache, url) == {:ok, nil}
    end

    test "use Pleroma's user agent in the request; don't pass the client's", %{conn: conn} do
      wanted_headers = [{"user-agent", Pleroma.Application.user_agent()}]

      Tesla.Mock.mock(fn %{url: "/user-agent", headers: ^wanted_headers} ->
        %Tesla.Env{
          status: 200,
          body: ""
        }
      end)

      conn =
        conn
        |> Plug.Conn.put_req_header("user-agent", "fake/1.0")
        |> ReverseProxy.call("/user-agent")

      assert response(conn, 200)
    end

    test "closed connection", %{conn: conn} do
      ClientMock
      |> expect(:request, fn :get, "/closed", _, _, _ -> {:ok, 200, [], %{}} end)
      |> expect(:stream_body, fn _ -> {:error, :closed} end)
      |> expect(:close, fn _ -> :ok end)

      conn = ReverseProxy.call(conn, "/closed")
      assert conn.halted
    end
  end

  describe "max_body" do
    test "length returns error if content-length more than option", %{conn: conn} do
      assert capture_log(fn ->
               ReverseProxy.call(conn, "/huge-file", max_body_length: 4)
             end) =~
               "[error] Elixir.Pleroma.ReverseProxy: request to \"/huge-file\" failed: :body_too_large"

      assert {:ok, true} == Cachex.get(:failed_proxy_url_cache, "/huge-file")

      assert capture_log(fn ->
               ReverseProxy.call(conn, "/huge-file", max_body_length: 4)
             end) == ""
    end
  end

  describe "HEAD requests" do
    test "common", %{conn: conn} do
      ClientMock
      |> expect(:request, fn :head, "/head", _, _, _ ->
        {:ok, 200, [{"content-type", "text/html; charset=utf-8"}]}
      end)

      conn = ReverseProxy.call(Map.put(conn, :method, "HEAD"), "/head")
      assert html_response(conn, 200) == ""
    end
  end

  describe "returns error on" do
    test "500", %{conn: conn} do
      url = "/status/500"

      capture_log(fn -> ReverseProxy.call(conn, url) end) =~
        "[error] Elixir.Pleroma.ReverseProxy: request to /status/500 failed with HTTP status 500"

      assert Cachex.get(:failed_proxy_url_cache, url) == {:ok, true}

      {:ok, ttl} = Cachex.ttl(:failed_proxy_url_cache, url)
      assert ttl <= 60_000
    end

    test "400", %{conn: conn} do
      url = "/status/400"

      capture_log(fn -> ReverseProxy.call(conn, url) end) =~
        "[error] Elixir.Pleroma.ReverseProxy: request to /status/400 failed with HTTP status 400"

      assert Cachex.get(:failed_proxy_url_cache, url) == {:ok, true}
      assert Cachex.ttl(:failed_proxy_url_cache, url) == {:ok, nil}
    end

    test "403", %{conn: conn} do
      url = "/status/403"

      capture_log(fn ->
        ReverseProxy.call(conn, url, failed_request_ttl: :timer.seconds(120))
      end) =~
        "[error] Elixir.Pleroma.ReverseProxy: request to /status/403 failed with HTTP status 403"

      {:ok, ttl} = Cachex.ttl(:failed_proxy_url_cache, url)
      assert ttl > 100_000
    end
  end

  describe "keep request headers" do
    # setup [:headers_mock]

    test "header passes", %{conn: conn} do
      conn =
        Conn.put_req_header(
          conn,
          "accept",
          "text/html"
        )
        |> ReverseProxy.call("/headers")

      %{"headers" => headers} = json_response(conn, 200)
      assert headers["Accept"] == "text/html"
    end

    test "header is filtered", %{conn: conn} do
      conn =
        Conn.put_req_header(
          conn,
          "accept-language",
          "en-US"
        )
        |> ReverseProxy.call("/headers")

      %{"headers" => headers} = json_response(conn, 200)
      refute headers["Accept-Language"]
    end
  end

  test "returns 400 on non GET, HEAD requests", %{conn: conn} do
    conn = ReverseProxy.call(Map.put(conn, :method, "POST"), "/ip")
    assert conn.status == 400
  end

  describe "cache resp headers" do
    test "add cache-control", %{conn: conn} do
      ClientMock
      |> expect(:request, fn :get, "/cache", _, _, _ ->
        {:ok, 200, [{"ETag", "some ETag"}], %{}}
      end)
      |> expect(:stream_body, fn _ -> :done end)

      conn = ReverseProxy.call(conn, "/cache")
      assert {"cache-control", "public, max-age=1209600"} in conn.resp_headers
    end
  end

  describe "response content disposition header" do
    test "not atachment", %{conn: conn} do
      # disposition_headers_mock([
      #  {"content-type", "image/gif"},
      #  {"content-length", "0"}
      # ])

      conn = ReverseProxy.call(conn, "/disposition")

      assert {"content-type", "image/gif"} in conn.resp_headers
    end

    test "with content-disposition header", %{conn: conn} do
      # disposition_headers_mock([
      #  {"content-disposition", "attachment; filename=\"filename.jpg\""},
      #  {"content-length", "0"}
      # ])

      conn = ReverseProxy.call(conn, "/disposition")

      assert {"content-disposition", "attachment; filename=\"filename.jpg\""} in conn.resp_headers
    end
  end
end

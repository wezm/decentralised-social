defmodule Pleroma.ReverseProxy.Client.Tesla do
  @behaviour Pleroma.ReverseProxy.Client

  @adapters [Tesla.Adapter.Gun]
  alias Pleroma.HTTP

  def request(method, url, headers, body, opts \\ []) do
    adapter_opts =
      Keyword.get(opts, :adapter, [])
      |> Keyword.put(:chunks_response, true)

    with {:ok, response} <-
           HTTP.request(method, url, body, headers, Keyword.put(opts, :adapter, adapter_opts)) do
      {:ok, response.status, response.headers, response.body}
    else
      {:error, error} -> {:error, error}
    end
  end

  def stream_body(%{fin: true}), do: :done

  def stream_body(client) do
    case read_chunk!(client) do
      {:fin, body} -> {:ok, body, Map.put(client, :fin, true)}
      {:nofin, part} -> {:ok, part, client}
    end
  end

  defp read_chunk!(client) do
    adapter = Application.get_env(:tesla, :adapter)

    unless adapter in @adapters do
      raise "#{adapter} doesn't support reading body in chunks"
    end

    adapter.read_chunk(client)
  end

  def close(client) do
    adapter = Application.get_env(:tesla, :adapter)

    unless adapter in @adapters do
      raise "#{adapter} doesn't support closing connection"
    end

    adapter.close(client)
  end
end

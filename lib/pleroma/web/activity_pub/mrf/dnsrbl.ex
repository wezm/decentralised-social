# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.DnsRblPolicy do
  @moduledoc "Dynamic activity filtering based on public database"
  @behaviour Pleroma.Web.ActivityPub.MRF

  alias Pleroma.Config

  defp check_rbl(%{host: actor_host} = _actor_info, object) do
    rblconfig = Config.get([:mrf_dnsrbl])
    rblhost = rblconfig[:nameserver]

    {:ok, rblnsip} =
      case rblhost |> String.to_charlist() |> :inet_parse.address() do
        {:ok, _} -> rblhost |> String.to_charlist() |> :inet_parse.address()
        _ -> {:ok, rblhost |> :inet_res.lookup(:in, :a) |> Enum.random()}
      end

    rblport = rblconfig[:port]

    rblzone = rblconfig[:zone] || rblhost

    query = (actor_host <> "." <> rblzone) |> String.to_charlist()

    rbl_response =
      :inet_res.lookup(query, :in, :a, nameservers: [{rblnsip, rblport}], timeout: 1000, retry: 1)

    cond do
      actor_host == Config.get([Pleroma.Web.Endpoint, :url, :host]) -> {:ok, object}
      rbl_response != [] -> {:reject, "[DNSRBLPolicy]"}
      true -> {:ok, object}
    end
  end

  @impl true
  def filter(%{"actor" => actor} = object) do
    actor_info = URI.parse(actor)

    with {:ok, object} <- check_rbl(actor_info, object) do
      {:ok, object}
    else
      _ -> {:reject, "[DNSRBLPolicy]"}
    end
  end

  @impl true
  def filter(object), do: {:ok, object}

  @impl true
  def describe do
    mrf_dnsrbl =
      Config.get(:mrf_dnsrbl)
      |> Enum.into(%{})

    {:ok, %{mrf_dnsrbl: mrf_dnsrbl}}
  end

  @impl true
  def config_description do
    %{
      key: :mrf_dnsrbl,
      related_policy: "Pleroma.Web.ActivityPub.MRF.DnsRblPolicy",
      label: "MRF DNSRBL",
      description: "DNS RealTime Blackhole Policy",
      children: [
        %{
          key: :nameserver,
          type: {:string},
          description: "DNSRBL NameServer to Query",
          suggestions: ["bl.pleroma.com"]
        },
        %{
          key: :port,
          type: {:string},
          description: "Nameserver port",
          suggestions: ["53"]
        },
        %{
          key: :zone,
          type: {:string},
          description:
            "Zone for querying, if unable to detect because nameserver is an IP address",
          suggestions: ["bl.pleroma.com"]
        }
      ]
    }
  end
end

# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.DnsRblPolicy do
  @moduledoc "Dynamic activity filtering based on public database"
  @behaviour Pleroma.Web.ActivityPub.MRF

  alias Pleroma.Config

  defp check_rbl(%{host: actor_host} = _actor_info, object) do
    rblconfig = Config.get([:mrf_dnsrbl])

    # :nameserver is the RBL server we want to query
    rblhost = rblconfig[:nameserver]

    # We have to query the nameserver's by IP, so look it up if an IP address wasn't
    # provided in the config.
    # You may want this to be a hostname with round-robin A records for basic load
    # balancing, so we try that.
    {:ok, rblnsip} =
      case rblhost |> String.to_charlist() |> :inet_parse.address() do
        {:ok, _} -> rblhost |> String.to_charlist() |> :inet_parse.address()
        _ -> {:ok, rblhost |> String.to_charlist() |> :inet_res.lookup(:in, :a) |> Enum.random()}
      end

    rblport = rblconfig[:port]

    # If the provided nameserver was an IP, we also need to know the zone because we can't
    # derive it from the hostname. If the DNSRBL server software is configured to use "bl.pleroma.com"
    # -- irrespective of the actual hostname/IP used to reach it --
    # we need the configured zone as queries are nested under the zone. e.g., if you're checking the
    # status of pleroma.host you are querying for:
    #
    # dig @nameserverip pleroma.host.bl.pleroma.com. in A
    #
    rblzone = rblconfig[:rblzone] || rblhost

    # concatenate the host we're checking with the zone, e.g., "pleroma.host" <> . <> "bl.pleroma.com" <> .
    # trim off duplicate trailing period in case it was supplied in the config.
    query =
      (actor_host <> "." <> rblzone <> ".")
      |> String.replace_suffix("..", ".")
      |> String.to_charlist()

    # Timeout of 1s, retry 1
    # We will only be using UDP for queries, so if the DNSRBL server is > 500ms away it
    # may not work. However you wouldn't want it to be this far away or it will slow things
    # down. I think we should probably try to cache entries in cachex too, maybe 300s TTL ?
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
          key: :rblzone,
          type: {:string},
          description:
            "Zone for querying, if unable to detect because nameserver is an IP address",
          suggestions: ["bl.pleroma.com"]
        }
      ]
    }
  end
end

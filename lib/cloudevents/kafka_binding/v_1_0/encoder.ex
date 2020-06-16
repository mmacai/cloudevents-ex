defmodule Cloudevents.KafkaBinding.V_1_0.Encoder do
  @moduledoc false

  @spec to_binary_content_mode(Cloudevents.t()) ::
          {Cloudevents.kafka_body(), Cloudevents.kafka_headers()}
  def to_binary_content_mode(event) do
    body =
      case event.data do
        nil -> ""
        data -> Jason.encode!(data)
      end

    standard_headers =
      [
        {"content-type", "application/json"},
        {"ce_specversion", "1.0"},
        {"ce_type", event.type},
        {"ce_source", event.source},
        {"ce_id", event.id}
      ]
      |> add_if_set(event, :subject, as: "ce_subject")
      |> add_if_set(event, :time, as: "ce_time")

    extensions_as_headers = for {name, value} <- event.extensions, do: {"ce_#{name}", value}

    {body, standard_headers ++ extensions_as_headers}
  end

  # ---

  defp add_if_set(headers, event, key, as: header_name) do
    case Map.get(event, key) do
      nil -> headers
      val -> headers ++ [{header_name, val}]
    end
  end

  # ---

  @spec to_structured_content_mode(Cloudevents.t(), :json | :avro_binary) ::
          {:ok, {Cloudevents.kafka_body(), Cloudevents.kafka_headers()}} | {:error, term}
  def to_structured_content_mode(event, event_format)

  def to_structured_content_mode(event, :json) do
    body = Cloudevents.to_json(event)
    headers = [{"content-type", "application/cloudevents+json"}]
    {:ok, {body, headers}}
  end

  def to_structured_content_mode(event, :avro_binary) do
    headers = [{"content-type", "application/cloudevents+avro"}]

    case Cloudevents.to_avro(event) do
      {:ok, body} ->
        {:ok, {body, headers}}

      {:error, error} ->
        {:error, "Failed to encode Kafka message in structured content mode: #{inspect(error)}"}
    end
  end
end

defmodule Nomure.Database.Coder.GraphValue do
  @moduledoc """
  A module that specifies how the data is serialized as a value.

  It uses simple binary serialization to make it easier to port into another languages bindings

  CAN'T BE USED AS A TUPLE VALUE! For that use `FDB.Coder.Dynamic` that uses FDB standarts to preserve order
  """
  use FDB.Coder.Behaviour

  import Nomure.Database.Coder.Guards,
    only: [is_long_string: 1]

  @datetime_header 0x07
  @date_header 0x08
  @time_header 0x09
  @string_compressed_header 0x0A

  @max_buffer_size 10000

  @spec new() :: FDB.Coder.t()
  def new() do
    %FDB.Coder{module: __MODULE__, opts: nil}
  end

  @impl true
  def encode(value, _) when is_long_string(value) do
    # header - string value
    # we compress it to save storage space, tho small string can be a bit bigger (due to zstd header)
    # can help you a lot of compressing large pieces of text
    # TODO make it optional to the user? Tho it just will consume more storage space, with no
    # performance impact at all

    compressed = ExZstd.compress(value)

    raise_if_too_big(compressed, true)

    Msgpax.Bin.new(<<@string_compressed_header>> <> compressed)
    |> Msgpax.pack!()
    |> IO.iodata_to_binary()
  rescue
    _ -> raise Nomure.Error.EncodeValueError, value: value
  end

  def encode(%Date{} = value, _) do
    # header - string value
    # we compress it to save storage space, tho small string can be a bit bigger (due to zstd header)
    # can help you a lot of compressing large pieces of text
    # TODO make it optional to the user? Tho it just will consume more storage space, with no
    # performance impact at all

    value = Date.to_iso8601(value)

    Msgpax.Bin.new(<<@date_header>> <> value)
    |> Msgpax.pack!()
    |> IO.iodata_to_binary()
  rescue
    _ -> raise Nomure.Error.EncodeValueError, value: value
  end

  def encode(%Time{} = value, _) do
    # header - string value
    # we compress it to save storage space, tho small string can be a bit bigger (due to zstd header)
    # can help you a lot of compressing large pieces of text
    # TODO make it optional to the user? Tho it just will consume more storage space, with no
    # performance impact at all

    value = Time.to_iso8601(value)

    Msgpax.Bin.new(<<@time_header>> <> value)
    |> Msgpax.pack!()
    |> IO.iodata_to_binary()
  rescue
    _ -> raise Nomure.Error.EncodeValueError, value: value
  end

  def encode(value, _) do
    value
    |> Msgpax.pack!()
    |> IO.iodata_to_binary()
  rescue
    _ -> raise Nomure.Error.EncodeValueError, value: value
  end

  @impl true
  def decode(value, _) do
    case Msgpax.unpack!(value) do
      <<@string_compressed_header, compressed::binary>> ->
        {compressed |> ExZstd.decompress(), ""}

      <<@datetime_header, timestamp::binary>> ->
        {timestamp |> DateTime.from_iso8601() |> elem(1), ""}

      <<@date_header, timestamp::binary>> ->
        {timestamp |> Date.from_iso8601!(), ""}

      <<@time_header, timestamp::binary>> ->
        {timestamp |> Time.from_iso8601!(), ""}

      nil ->
        {"nil", ""}

      value ->
        {value, ""}
    end
  end

  defp raise_if_too_big(value, compressed?) do
    size = byte_size(value)

    if size > @max_buffer_size do
      # TODO values in FDB cannot be longer than 10KB, tho we could add chunking it but it adds complexity
      raise Nomure.Error.NodeValueTooBig,
        max_size: @max_buffer_size,
        current_size: size,
        compressed?: compressed?
    end
  end
end

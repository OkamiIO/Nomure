defmodule Nomure.Database.Coder.GraphValue do
  @moduledoc """
  A module that specifies how the data is serialized as a value.

  It uses simple binary serialization to make it easier to port into another languages bindings

  CAN'T BE USED AS A TUPLE VALUE! For that use `FDB.Coder.Dynamic` that uses FDB standarts
  """
  use FDB.Coder.Behaviour

  import Nomure.Database.Coder.Guards,
    only: [is_int: 1, is_long: 1, is_short: 1, is_long_string: 1, is_byte: 1]

  @nil_header <<0x00>>
  @uid_header <<0x01>>
  @byte_header <<0x02>>
  @short_header <<0x03>>
  @int32_header <<0x04>>
  @int64_header <<0x05>>
  @float_header <<0x06>>
  @bool_true_header <<0x07>>
  @bool_false_header <<0x08>>
  @string_header <<0x09>>
  @string_compressed_header <<0x0A>>

  @string_size Application.get_env(:nomure, :max_string_size_uncompress, 32)
  @max_buffer_size 10000

  @spec new() :: FDB.Coder.t()
  def new() do
    %FDB.Coder{module: __MODULE__, opts: nil}
  end

  @impl true
  def encode(<<_value::little-integer-unsigned-size(128)>> = value, _) do
    @uid_header <> value
  end

  def encode("", _) do
    @nil_header
  end

  def encode(nil, _) do
    @nil_header
  end

  # TODO use kind of SIMD compression integer? hmm (Tho I don't know if is a real use for it here)
  def encode(value, _) when is_byte(value) do
    @byte_header <> <<value::8>>
  end

  def encode(value, _) when is_short(value) do
    @short_header <> <<value::16>>
  end

  def encode(value, _) when is_int(value) do
    @int32_header <> <<value::32>>
  end

  def encode(value, _) when is_long(value) do
    @int64_header <> <<value::64>>
  end

  def encode(value, _) when is_float(value) do
    @float_header <> <<value::float-64>>
  end

  def encode(value, _) when is_long_string(value) do
    # header - string size - string value
    # we compress it to save storage space, tho small string can be a bit bigger (due to zstd header)
    # can help you a lot of compressing large pieces of text
    # TODO make it optional to the user? Tho it just will consume more storage space, with no
    # performance impact at all

    compressed = ExZstd.compress(value)

    raise_if_too_big(compressed, true)

    @string_compressed_header <> <<byte_size(compressed)::@string_size>> <> compressed
  end

  def encode(value, _) when is_binary(value) do
    # header - string size - string value

    raise_if_too_big(value, false)

    @string_header <> <<byte_size(value)::@string_size>> <> value
  end

  def encode(true, _) do
    @bool_true_header
  end

  def encode(false, _) do
    @bool_false_header
  end

  def encode(value, _) do
    raise Nomure.Error.EncodeValueError, value: value
  end

  @impl true
  def decode(<<@nil_header, rest::binary>>, _) do
    # We return an string in nil because if a key does not exist it will return nil as wells
    {"nil", rest}
  end

  def decode(@uid_header <> <<value::little-integer-unsigned-size(128), rest::binary>>, _) do
    {value, rest}
  end

  def decode(@byte_header <> <<value::8, rest::binary>>, _) do
    {value, rest}
  end

  def decode(@short_header <> <<value::16, rest::binary>>, _) do
    {value, rest}
  end

  def decode(@int32_header <> <<value::32, rest::binary>>, _) do
    {value, rest}
  end

  def decode(@int64_header <> <<value::64, rest::binary>>, _) do
    {value, rest}
  end

  def decode(@float_header <> <<value::float-64, rest::binary>>, _) do
    {value, rest}
  end

  def decode(<<@bool_true_header, rest::binary>>, _) do
    {true, rest}
  end

  def decode(<<@bool_false_header, rest::binary>>, _) do
    {false, rest}
  end

  def decode(
        @string_header <>
          <<string_size::@string_size, string::binary-size(string_size), rest::binary>>,
        _
      ) do
    {string, rest}
  end

  def decode(
        @string_compressed_header <>
          <<string_size::@string_size, compressed::binary-size(string_size), rest::binary>>,
        _
      ) do
    {compressed |> ExZstd.decompress(), rest}
  end

  defp raise_if_too_big(value, compressed?) do
    size = byte_size(value)

    if size > @max_buffer_size do
      # TODO values in FDB cannot be longer than 10KB, do we throw and error if the file is too big?
      # Or we must implement string chunking
      raise Nomure.Error.NodeValueTooBig,
        max_size: @max_buffer_size,
        current_size: size,
        compressed?: compressed?
    end
  end
end

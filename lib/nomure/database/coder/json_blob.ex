defmodule Nomure.Database.Coder.JsonBlob do
  use FDB.Coder.Behaviour

  @spec new() :: FDB.Coder.t()
  def new() do
    %FDB.Coder{module: __MODULE__, opts: nil}
  end

  @impl true
  def encode(value, _) when is_map(value) or is_list(value) do
    result_value =
      Jason.encode!(value)
      # most of the time beign a raw value, without dic is gonna be bigger then the raw json string
      # but shorter than the fdb version
      |> :zstd.compress()

    length = byte_size(result_value)

    # We save the size and the result
    <<length::integer-big-32>> <> result_value
  end

  @impl true
  def decode(<<length::integer-big-32, json::binary-size(length), rest::binary>>, _) do
    {json |> :zstd.decompress() |> Jason.decode!(), rest}
  end
end

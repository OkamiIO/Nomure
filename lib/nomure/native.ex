defmodule Nomure.Native do
  @moduledoc false
  use Rustler, otp_app: :nomure, crate: :nomure_native

  # TEST ONLY!!!
  def tokenize(), do: tokenize("Más espacios comprimidos en el espacio tiempo", false)

  def tokenize(text), do: tokenize(text, false)
  def tokenize(_text, _is_cjk), do: error()

  defp error, do: :erlang.nif_error(:nif_not_loaded)
end

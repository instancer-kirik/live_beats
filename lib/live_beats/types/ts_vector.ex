defmodule LiveBeats.Types.TsVector do
  @behaviour Ecto.Type

  def type, do: :tsvector

  # Casting from external data (e.g. forms, API)
  def cast(value) when is_binary(value), do: {:ok, value}
  def cast(value) when is_nil(value), do: {:ok, nil}
  def cast(_), do: :error

  # Loading from the database
  def load(value), do: {:ok, value}

  # Dumping to the database
  def dump(value) when is_binary(value), do: {:ok, value}
  def dump(nil), do: {:ok, nil}
  def dump(_), do: :error

  def embed_as(_), do: :self

  def equal?(term1, term2), do: term1 == term2
end

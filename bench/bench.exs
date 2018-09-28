alias FDB.{Transaction, Database, Cluster, KeySelectorRange}
alias FDB.Coder.{Tuple, ByteString, Subspace, LittleEndianInteger}

:ok = FDB.start(510)

coder =
  Transaction.Coder.new(
    Subspace.new(
      {"ts", ByteString.new()},
      Tuple.new({
        LittleEndianInteger.new(64),
        # website
        ByteString.new()
      })
    ),
    ByteString.new()
  )

coder2 =
  Transaction.Coder.new(
    Subspace.new(
      {"ts2", ByteString.new()},
      Tuple.new({
        LittleEndianInteger.new(64)
      })
    ),
    ByteString.new()
  )

db =
  Cluster.create()
  |> Database.create(%{coder: coder})

FDB.Database.transact(db, fn transaction ->
  Nomure.TransactionUtils.set_transaction(
    transaction,
    {1, "synopsys"},
    "The eccentric, self-proclaimed mad scientist Rintarou Okabe has become a shell of his former self. Depressed and traumatized after failing to rescue his friend Makise Kurisu, he has decided to forsake his mad scientist alter ego and live as an ordinary college student. Surrounded by friends who know little of his time travel experiences, Okabe spends his days trying to forgetthe horrors of his adventures alone.",
    coder
  )

  Nomure.TransactionUtils.set_transaction(
    transaction,
    {1, "name"},
    "Steinz:Gate",
    coder
  )

  Nomure.TransactionUtils.set_transaction(
    transaction,
    {1, "episodes"},
    "24",
    coder
  )

  Nomure.TransactionUtils.set_transaction(
    transaction,
    {1},
    :zstd.compress(
      "{\"name\":\"Steinz;gate\",\"synopsis\":\"The eccentric, self-proclaimed mad scientist Rintarou Okabe has become a shell of his former self. Depressed and traumatized after failing to rescue his friend Makise Kurisu, he has decided to forsake his mad scientist alter ego and live as an ordinary college student. Surrounded by friends who know little of his time travel experiences, Okabe spends his days trying to forgetthe horrors of his adventures alone.\",\"episodes\":\"24\"}"
    ),
    coder2
  )
end)

compressed =
  :zstd.compress(
    "The eccentric, self-proclaimed mad scientist Rintarou Okabe has become a shell of his former self. Depressed and traumatized after failing to rescue his friend Makise Kurisu, he has decided to forsake his mad scientist alter ego and live as an ordinary college student. Surrounded by friends who know little of his time travel experiences, Okabe spends his days trying to forgetthe horrors of his adventures alone."
  )

Benchee.run(%{
  "jason encode speed" => fn ->
    Jason.encode!(%{
      "name" => "Steinz;gate",
      "synopsis" =>
        "The eccentric, self-proclaimed mad scientist Rintarou Okabe has become a shell of his former self. Depressed and traumatized after failing to rescue his friend Makise Kurisu, he has decided to forsake his mad scientist alter ego and live as an ordinary college student. Surrounded by friends who know little of his time travel experiences, Okabe spends his days trying to forgetthe horrors of his adventures alone.",
      "episodes" => "24"
    })
  end,
  "jason decode speed" => fn ->
    Jason.decode!(
      "{\"name\":\"Steinz;gate\",\"synopsis\":\"The eccentric, self-proclaimed mad scientist Rintarou Okabe has become a shell of his former self. Depressed and traumatized after failing to rescue his friend Makise Kurisu, he has decided to forsake his mad scientist alter ego and live as an ordinary college student. Surrounded by friends who know little of his time travel experiences, Okabe spends his days trying to forgetthe horrors of his adventures alone.\",\"episodes\":\"24\"}"
    )
  end,
  "uncompress speed" => fn ->
    :zstd.decompress(compressed)
  end,
  "compress speed" => fn ->
    :zstd.compress(
      "The eccentric, self-proclaimed mad scientist Rintarou Okabe has become a shell of his former self. Depressed and traumatized after failing to rescue his friend Makise Kurisu, he has decided to forsake his mad scientist alter ego and live as an ordinary college student. Surrounded by friends who know little of his time travel experiences, Okabe spends his days trying to forgetthe horrors of his adventures alone."
    )
  end,
  "get compress data" => fn ->
    FDB.Database.transact(db, fn transaction ->
      {:ok, transaction, value} =
        Nomure.TransactionUtils.get_transaction(transaction, {1}, coder2)

      :zstd.decompress(value) |> Jason.decode!()
    end)
  end,
  "get uncompress data" => fn ->
    FDB.Database.transact(db, fn transaction ->
      range = KeySelectorRange.starts_with({1})

      FDB.Transaction.get_range(transaction, range, %{coder: coder})
      |> Enum.to_list()
    end)
  end
})

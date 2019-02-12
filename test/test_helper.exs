:os.cmd(~S"fdbcli --exec \"writemode on; clearrange \x00 \xff;\"" |> String.to_charlist())

Nomure.start()

# ExUnit.start()
ExUnit.start(exclude: [:expensive])

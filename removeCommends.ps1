[IO.Directory]::SetCurrentDirectory((Convert-Path (Get-Location -PSProvider FileSystem)))
$filetxt = [IO.File]::ReadAllText("c:\publish\ab.config")
$filetxt = ($filetxt -replace "(?ms)^\s*<!--\s*[\r\n]*\s*\*\*\*\*\*[\s\S\n]*?-->[\r\n]*", "")
Set-Content -Path "c:\publish\ab.config" -Value $filetxt

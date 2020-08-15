#.\removeComment.ps1 "c:\publish\ab.config" "(?ms)^\s*<!--\s*[\r\n]*\s*\*\*\*\*\*[\s\S\n]*?-->[\r\n]*"

$webConfigFilePath=$args[0]
$pattern=$args[1]
[IO.Directory]::SetCurrentDirectory((Convert-Path (Get-Location -PSProvider FileSystem)))
$filetxt = [IO.File]::ReadAllText($webConfigFilePath)
$filetxt = ($filetxt -replace $pattern, "")
Set-Content -Path $webConfigFilePath -Value $filetxt

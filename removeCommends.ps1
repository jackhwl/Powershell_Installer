#.\removeComment.ps1 -FilePath "c:\publish\ab.config" 

param
(
	$FilePath = "C:\\publish\\Web.config",
	$Pattern = "(?ms)^\s*<!--\s*[\r\n]*\s*\*\*\*\*\*[\s\S\n]*?-->[\r\n]*"
)
[IO.Directory]::SetCurrentDirectory((Convert-Path (Get-Location -PSProvider FileSystem)))
$filetxt = [IO.File]::ReadAllText($FilePath)
$filetxt = ($filetxt -replace $Pattern, "")
Set-Content -Path $FilePath -Value $filetxt

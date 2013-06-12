param
(
	$Logfile = "log.txt",
	$SilentMode = $true
)
if ( $Args.Length -gt 0 ) {
    $Logfile = $Args[0]
	$SilentMode = $Args[1]
}

function Test-Key
{
	param
	(
		[string]$path, 
		[string]$key
	)
    if(!(Test-Path $path)) { return $false }
    if ((Get-ItemProperty $path).$key -eq $null) { return $false }
    return $true
}
function Test-KeyValue
{
	param
	(
		[string]$path, 
		[string]$key, 
		[string]$value
	)
    if(!(Test-Path $path)) { return $false }
    if ((Get-ItemProperty $path).$key -eq $value) { return $true }
    return $false
}
function Get-KeyValue
{
	param
	(
		[string]$path, 
		[string]$key
	)
    return (Get-ItemProperty $path).$key
}
function Get-Choice
{
	param
	(
		$caption,
		$message,
		$defaultChoices
	)
	$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""
	$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""
	$choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes,$no)
	$result = $Host.UI.PromptForChoice($caption,$message,$choices,$defaultChoices)
	return $result
}
function Get-Password
{
	param
	(
		$caption
	)
	echo ""
	echo "===================================================================="
	$pass = Read-Host $caption -AsSecureString
	$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass))
	
	return $password
}
function Remove-Application
{
	param
	(
		$siteName,
		$applicationName
	)
	#####      Remove Existing Application
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe delete app """ + $siteName + "/" + $applicationName +""""
	log(Invoke-Expression $appcmd)
}
function Remove-ApplicationPool
{
	param
	(
		$applicationPoolName
	)
	#####      Remove Existing ApplicationPool
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe delete apppool " + $applicationPoolName
	log(Invoke-Expression $appcmd)
}

function setupFrenchLanguagePack
{
	param
	(
		$InstallFolder
	)
	$frenchPack = Get-WmiObject -Class Win32_Product | Where {$_.Name -match 'Microsoft .NET Framework 4 Extended FRA Language Pack' }
	if ($frenchPack -eq $NULL) { 
		echo "#####      Install .NetFramwork4 french language pack"
		$frenLangPackPath = Join-Path (Join-Path $InstallFolder installer) dotNetFx40LP_Full_x86_x64fr.exe
		Start-Process $frenLangPackPath -Wait
	} 
}
function log
{
   Param 
   (
		[string]$logstring
   )
   if (!$SilentMode)
   {
		echo "=========  $logstring"
   }
   Add-content $Logfile -value $logstring
}

#***********************************************************************
#************************* DB Powershell Init  *************************
#***********************************************************************
<#
$runDBscripts = "true" 
if ($runDBscripts -eq "true")
{
	# Initialize-SqlpsEnvironment.ps1
	#
	# Loads the SQL Server provider extensions
	#
	# Usage: Powershell -NoExit -Command "& '.\Initialize-SqlPsEnvironment.ps1'"
	#
	# Change log:
	# June 14, 2008: Michiel Wories
	#   Initial Version
	# June 17, 2008: Michiel Wories
	#   Fixed issue with path that did not allow for snapin\provider:: prefix of path
	#   Fixed issue with provider variables. Provider does not handle case yet
	#   that these variables do not exist (bug has been filed)
	 
	$ErrorActionPreference = "Stop"
	 
	$sqlpsreg="HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.SqlServer.Management.PowerShell.sqlps"
	 
	if (Get-ChildItem $sqlpsreg -ErrorAction "SilentlyContinue")
	{
		throw "SQL Server Powershell is not installed."
	}
	else
	{
		$item = Get-ItemProperty $sqlpsreg
		$sqlpsPath = [System.IO.Path]::GetDirectoryName($item.Path)
	}
	 

	#
	# Preload the assemblies. Note that most assemblies will be loaded when the provider
	# is used. if you work only within the provider this may not be needed. It will reduce
	# the shell's footprint if you leave these out.
	#
	$assemblylist = 
	"Microsoft.SqlServer.Smo",
	"Microsoft.SqlServer.Dmf ",
	"Microsoft.SqlServer.SqlWmiManagement ",
	"Microsoft.SqlServer.ConnectionInfo ",
	"Microsoft.SqlServer.SmoExtended ",
	"Microsoft.SqlServer.Management.RegisteredServers ",
	"Microsoft.SqlServer.Management.Sdk.Sfc ",
	"Microsoft.SqlServer.SqlEnum ",
	"Microsoft.SqlServer.RegSvrEnum ",
	"Microsoft.SqlServer.WmiEnum ",
	"Microsoft.SqlServer.ServiceBrokerEnum ",
	"Microsoft.SqlServer.ConnectionInfoExtended ",
	"Microsoft.SqlServer.Management.Collector ",
	"Microsoft.SqlServer.Management.CollectorEnum"
	 

	foreach ($asm in $assemblylist)
	{
		$asm = [Reflection.Assembly]::LoadWithPartialName($asm)
	}
	 
	#
	# Set variables that the provider expects (mandatory for the SQL provider)
	#
	Set-Variable -scope Global -name SqlServerMaximumChildItems -Value 0
	Set-Variable -scope Global -name SqlServerConnectionTimeout -Value 30
	Set-Variable -scope Global -name SqlServerIncludeSystemObjects -Value $false
	Set-Variable -scope Global -name SqlServerMaximumTabCompletion -Value 1000
	 
	#
	# Load the snapins, type data, format data
	#
	Push-Location
	cd $sqlpsPath
	#Remove-PSSnapin SqlServerCmdletSnapin100
	Add-PSSnapin SqlServerCmdletSnapin100
	Add-PSSnapin SqlServerProviderSnapin100
	Update-TypeData -PrependPath SQLProvider.Types.ps1xml 
	update-FormatData -prependpath SQLProvider.Format.ps1xml 
	Pop-Location
	 
	Write-Host -ForegroundColor Yellow 'SQL Server Powershell Extensions Are Loaded.'
	Write-Host
	#add-pssnapin SqlServerCmdletSnapin100		
}
#>

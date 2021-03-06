$Policy = "Unrestricted"
If ((get-ExecutionPolicy) -ne $Policy) {
  Set-ExecutionPolicy $Policy -Force
}
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

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

[xml]$c = Get-Content "site.config" 
$InstallFolder = "Package"

#***********************************************************************
#*********************  MACRO Replace Operation	************************
#***********************************************************************
function Get-Framework-Versions()
{
    $installedFrameworks = @()
    if(Test-Key "HKLM:\Software\Microsoft\.NETFramework\Policy\v1.0" "3705") { $installedFrameworks += "1.0" }
    if(Test-Key "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v1.1.4322" "Install") { $installedFrameworks += "1.1" }
    if(Test-Key "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v2.0.50727" "Install") { $installedFrameworks += "2.0" }
    if(Test-Key "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v3.0\Setup" "InstallSuccess") { $installedFrameworks += "3.0" }
    if(Test-Key "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v3.5" "Install") { $installedFrameworks += "3.5" }
    if(Test-Key "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Client" "Install") { $installedFrameworks += "4.0c" }
    if(Test-Key "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Full" "Install") { $installedFrameworks += "4.0" }   
     
    return $installedFrameworks
}
 function Test-Key([string]$path, [string]$key)
{
    if(!(Test-Path $path)) { return $false }
    if ((Get-ItemProperty $path).$key -eq $null) { return $false }
    return $true
}
function Test-KeyValue([string]$path, [string]$key, [string]$value)
{
    if(!(Test-Path $path)) { return $false }
    if ((Get-ItemProperty $path).$key -eq $value) { return $true }
    return $false
}
function Get-KeyValue([string]$path, [string]$key)
{
    return (Get-ItemProperty $path).$key
}
function ConfigIIS7()
{
	#echo "#####      Allow Asp.net 4.0"
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config ""/section:isapiCgiRestriction"" ""/[path='$env:windir\Microsoft.NET\Framework\v4.0.30319\aspnet_isapi.dll'].allowed:True"""
	Invoke-Expression $appcmd
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config ""/section:isapiCgiRestriction"" ""/[path='$env:windir\Microsoft.NET\Framework64\v4.0.30319\aspnet_isapi.dll'].allowed:True"""
	Invoke-Expression $appcmd

	#echo "#####      Enable parent path"
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $d.webSite.siteName + """ ""/section:asp"" ""/enableParentPaths:true"" ""/commit:appHost"""
	Invoke-Expression $appcmd

	#echo "#####      Remove Custom error page"
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $d.webSite.siteName + """ ""/section:httpErrors"" /-""[statusCode='500', subStatusCode='0']"""
	echo $appcmd
	Invoke-Expression $appcmd
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $d.webSite.siteName + """ ""/section:httpErrors"" /-""[statusCode='500', subStatusCode='100']"""
	echo $appcmd
	Invoke-Expression $appcmd
	
	#echo "#####      Add Custom error page"
	$errorPagePath = "/" + $coreApplicationName + "/Common/ASPError.asp"
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $d.webSite.siteName + """ ""/section:httpErrors"" /+""[statusCode='500', subStatusCode='0', path='" + $errorPagePath + "', responseMode='ExecuteURL']"""
	Invoke-Expression $appcmd
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $d.webSite.siteName + """ ""/section:httpErrors"" /+""[statusCode='500', subStatusCode='100', path='" + $errorPagePath + "', responseMode='ExecuteURL']"""
	Invoke-Expression $appcmd
}
function CheckPrerequisites()
{
	if (([string](Get-Framework-Versions)).IndexOf("4.0") -lt 0)
	{
		Write-Warning "This application requires .NET Framework 4.0. Please install the .NET Framework then run this installer again"
		break
	}
	if (!(Test-Key "HKLM:\Software\Microsoft\InetStp" "PathWWWRoot"))
	{
		Write-Warning "IIS does not appear to be installed correctly, the root directory is not set."
		break
	}
	if ((Get-KeyValue "HKLM:\Software\Microsoft\InetStp" "MajorVersion") -lt 7)
	{
		Write-Warning "This application requires IIS 7. Please install IIS 7 then run this installer again."
		break
	}
}
function CreateApplicationPool()
{
	echo "#####      Create ApplicationPool"
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe add apppool /name:""" + $d.webSite.applicationPool + """ /managedRuntimeVersion:v4.0 /managedPipelineMode:Classic"
	Invoke-Expression $appcmd
	echo "#####      Set ApplicationPool Identity"
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config /section:applicationPools " + """/[name='" + $d.webSite.applicationPool + "'].processModel.identityType:SpecificUser"" " + """/[name='" + $d.webSite.applicationPool + "'].processModel.userName:" + (Join-Path $d.webSite.applicationPoolIdentityDomain $d.webSite.applicationPoolIdentity) + """ " + """/[name='" + $d.webSite.applicationPool + "'].processModel.password:" + $d.webSite.applicationPoolIdentityPwd + """"
	Invoke-Expression $appcmd
	echo "#####      Enable 32-Bit Applications"
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set apppool /apppool.name:""" + $d.webSite.applicationPool + """ ""/enable32BitAppOnWin64:true"""
	Invoke-Expression $appcmd
}
function CreateApplication()
{
	echo "#####      Create Application under site"
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe add app /site.name:""" + $d.webSite.siteName + """ /path:/" + $d.webSite.applicationName +" /physicalPath:""" + (Join-Path $d.webSite.path "Asp\Website") + """"
	Invoke-Expression $appcmd
	echo "#####      Set Application's application pool"
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set app /app.name:""" + $d.webSite.siteName + "/" + $d.webSite.applicationName + """ /applicationPool:""" + $d.webSite.applicationPool + """"
	Invoke-Expression $appcmd
}
function CreateVirualDirectory()
{
	echo "#####      Create Virtual Directory Admin, Web, Common"
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe add vdir /app.name:""" + $d.webSite.siteName + "/" + $d.webSite.applicationName + """ /path:/Admin /physicalPath:""" + (Join-Path $coreAdminParentPath "Admin") + """"
	Invoke-Expression $appcmd
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe add vdir /app.name:""" + $d.webSite.siteName + "/" + $d.webSite.applicationName + """ /path:/Web /physicalPath:""" + (Join-Path $coreAdminParentPath "Web") + """"
	Invoke-Expression $appcmd
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe add vdir /app.name:""" + $d.webSite.siteName + "/" + $d.webSite.applicationName + """ /path:/Common /physicalPath:""" + (Join-Path $coreAdminParentPath "Common") + """"
	Invoke-Expression $appcmd
}
function ConfigApplication()
{
	echo "#####      Set site default page"
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $d.webSite.siteName + "/" + $d.webSite.applicationName + """ ""/section:defaultDocument"" ""/+files.[value='default.htm']"""
	Invoke-Expression $appcmd
	echo "#####      Send Errors to browser"
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $d.webSite.siteName + "/" + $d.webSite.applicationName + """ /section:system.webServer/asp /scriptErrorSentToBrowser:""True"""
	Invoke-Expression $appcmd
	echo "#####      Set Request filtering"
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $d.webSite.siteName + "/" + $d.webSite.applicationName + """ /section:requestfiltering /requestlimits.maxallowedcontentlength:60000000"
	Invoke-Expression $appcmd
}
function UpdateConnectionString()
{
	echo "#####      Modify Doxim.udl"
	$dbFilePath = Join-Path $d.webSite.path ASP\Data\Doxim.udl
	Set-ItemProperty $dbFilePath -name IsReadOnly -value $false	
	$dbFile = Get-Content $dbFilePath
	$dbFile = $dbFile -replace "DBSRVR", $d.dBServer.serverName
	$dbFile = $dbFile -replace "SQLDBNAME", $d.dBServer.dbName
	$dbFile = $dbFile -replace "SQLUSERNAME", $d.dBServer.userId
	$dbFile = $dbFile -replace "SQLPASSWORD", $d.dBServer.password
	Set-Content $dbFilePath $dbFile -Encoding Unicode
}
function SetupFrenchLanguagePack()
{
	$frenchPack = Get-WmiObject -Class Win32_Product | Where {$_.Name -match 'Microsoft .NET Framework 4 Extended FRA Language Pack' }
	if ($frenchPack -eq $NULL) { 
		echo "#####      Install .NetFramwork4 french language pack"
		$frenLangPackPath = Join-Path (Join-Path $InstallFolder installer) dotNetFx40LP_Full_x86_x64fr.exe
		Start-Process $frenLangPackPath -Wait
	} 
}
function CopyDirectorys
{
	if (Test-Path $d.webSite.path) 
	{ 
		if (!$coreSiteExists) { IISRESET }
		Remove-Item $d.webSite.path -recurse -force 
	}

	if ($coreSiteExists)
	{
		echo "#####      Copy Website only"
		Copy-Item -path (Join-Path $InstallFolder ECMweb\Website) -destination (Join-Path $d.webSite.path ASP\Website) -recurse -force 
		Copy-Item -path (Join-Path $InstallFolder ECMweb\Data) -destination (Join-Path $d.webSite.path ASP\Data) -recurse -force 
	}
	else
	{
		echo "#####      Copy Website and Lib"
		
		Copy-Item -path (Join-Path $InstallFolder ECMweb) -destination (Join-Path $d.webSite.path ASP) -recurse -force 
		Copy-Item -path (Join-Path $InstallFolder lib) -destination (Join-Path $d.webSite.path lib) -recurse -force 

		RegisterDll
	}
	Copy-Item -path (Join-Path (Join-Path $InstallFolder installer) Doxim.udl) -destination (Join-Path $d.webSite.path ASP\Data\Doxim.udl) -recurse -force 
}
function RegisterDll()
{
	#### comment RegisterCom.bat pause
	$batchFilePath = Join-Path (Join-Path $d.webSite.path lib) RegisterCom.bat
	$batchFileContent = Get-Content $batchFilePath
	$batchFileContent = $batchFileContent -replace "pause", "REM pause"
	Set-Content $batchFilePath $batchFileContent
	
	echo "#####      Run RegisterCom.bat"
	cd (Join-Path $d.webSite.path lib)
	echo (Join-Path $d.webSite.path lib)
	Start-Process $batchFilePath -NoNewWindow -Wait
	cd $scriptPath
	
	#### uncomment RegisterCom.bat pause
	$batchFileContent = Get-Content $batchFilePath
	$batchFileContent = $batchFileContent -replace "REM pause", "pause"
	Set-Content $batchFilePath $batchFileContent
}
function CleanUp()
{
	#del web.config
	$webConfigPath = Join-Path $d.webSite.path ASP\Website\web.config
	echo $webConfigPath
	if (Test-Path $webConfigPath) 
	{
		echo $webConfigPath
		Remove-Item $webConfigPath -recurse -force 
	}
}
##### Check Install Prerequisites	
CheckPrerequisites

$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""
$choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes,$no)

foreach ($d in $c.configuration.sites.site)
{
	switch ($d.type)
	{
		"application" 
		{
			$coreSiteExists = [boolean]::Parse($d.coreSite.exists)
			$poolExists = Test-Path ("IIS:\AppPools\"+$d.webSite.applicationPool)
			$siteExists = Test-Path ("IIS:\Sites\"+$d.WebSite.siteName+"\"+$d.WebSite.applicationName)
			$reInstallPool = $false
			$reInstallSite = $false
			#echo $d.webSite.siteName
			#echo ("IIS:\Sites\"+$d.webSite.siteName+"\"+$d.webSite.applicationName)
			
			if ($poolExists)
			{
				$caption = "Warning! applicationPool: "+$d.webSite.applicationPool+" already exists!!"
				$message = "Do you want to remove this applicationPool and reinstall a new one? "
				$result = $Host.UI.PromptForChoice($caption,$message,$choices,1)
				if($result -eq 0) { $reInstallPool = $true } else { $reInstallPool = $false } 
			}
			if ($siteExists)
			{
				$caption = "Warning! WebSite: "+$d.webSite.siteName+"\"+$d.webSite.applicationName+ " already exists!!"
				$message = "Do you want to remove this site and reinstall a new one? "
				$result = $Host.UI.PromptForChoice($caption,$message,$choices,1)
				if($result -eq 0) { $reInstallSite = $true } else { $reInstallSite = $false }
			}

			if ($siteExists -and $reInstallSite)
			{
				echo "#####      Remove Old Application"
				$appcmd = "$env:windir\system32\inetsrv\appcmd.exe delete app """ + $d.webSite.siteName + "/" + $d.webSite.applicationName +""""
				Invoke-Expression $appcmd
				if (Test-Path $d.webSite.path) 
				{ 
					if (!$coreSiteExists) { IISRESET }
					Remove-Item $d.webSite.path -recurse -force 
				}
				
				if ($poolExists -and $reInstallPool)
				{
					echo "#####      Remove Old ApplicationPool"
					$appcmd = "$env:windir\system32\inetsrv\appcmd.exe delete apppool " + $d.webSite.applicationPool
					Invoke-Expression $appcmd
				}
			}
			
			if (!$siteExists -or $reInstallSite)
			{
				$coreApplicationName = $d.coreSite.applicationName 
				$coreAdminParentPath = if ($coreSiteExists) {$d.coreSite.adminParentPath } else {Join-Path $d.webSite.path "Asp"}
				
				CopyDirectorys
				exit
				ConfigIIS7
				CreateApplicationPool
				CreateApplication
				CreateVirualDirectory
				ConfigApplication
				UpdateConnectionString
				CleanUp
	
				Write-Host "Doxim ECM Site: "$d.webSite.siteName"/"$d.webSite.applicationName" Complete Installed" -ForegroundColor "Green"
			}
			else
			{
				Write-Host "Found Previous Doxim ECM Site: "$d.webSite.siteName"/"$d.webSite.applicationName -ForegroundColor "Yellow"
			}
		}
	}
}


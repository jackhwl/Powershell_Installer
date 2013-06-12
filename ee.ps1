param
(
	[string]$configFile = "site.config",
	[string]$InstallFolder = "Package",
	[string]$applicationPoolIdentityPassword = "",
	[string]$dBServerPassword = ""
)
$Policy = "Unrestricted"
If ((get-ExecutionPolicy) -ne $Policy) {
  Set-ExecutionPolicy $Policy -Force
}
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$Logfile = Join-Path $scriptPath "log.txt"
Import-Module WebAdministration

function Get-Framework-Versions
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
function checkPrerequisites
{
	log("####  checkPrerequisites")
	if (!(Test-Key "HKLM:\Software\Microsoft\InetStp" "PathWWWRoot"))
	{
		log("IIS does not appear to be installed correctly, the root directory is not set.") | Write-Warning 
		$global:InstallSuccess = $false
	}
	if ($global:InstallSuccess -And ((Get-KeyValue "HKLM:\Software\Microsoft\InetStp" "MajorVersion") -lt 7))
	{
		log("This application requires IIS 7. Please install IIS 7 then run this installer again.") | Write-Warning 
		$global:InstallSuccess = $false
	}
	if ($global:InstallSuccess -And (([string](Get-Framework-Versions)).IndexOf("4.0") -lt 0))
	{
		log("This application requires .NET Framework 4.0. Please install the .NET Framework then run this installer again") | Write-Warning 
		$global:InstallSuccess = $false
	}
}
function checkExistingPool
{
	param
	(
		$poolExists,
		$silentMode,
		[ref]$reInstallPool
	)
	if ($poolExists)
	{
		if ($silentMode)
		{
			$reInstallPool.Value = $true
		}
		else
		{
			$caption = "Warning! applicationPool: "+$cfg.webSite.applicationPool+" already exists!!"
			$message = "Do you want to remove this applicationPool and reinstall a new one? "
			$result = Get-Choice $caption $message 1
			if($result -eq 0) { $reInstallPool.Value = $true } else { $reInstallPool.Value = $false } 
		}
	}
}
function checkExistingSite
{
	param
	(
		$poolExists,
		$silentMode,
		[ref]$reInstallSite
	)
	if ($siteExists)
	{
		if ($silentMode)
		{
			$reInstallSite.Value = $true
		}
		else
		{
			$caption = "Warning! WebSite: "+$cfg.webSite.siteName+"\"+$cfg.webSite.applicationName+ " already exists!!"
			$message = "Do you want to remove this site and reinstall a new one? "
			$result = Get-Choice $caption $message 1
			if($result -eq 0) { $reInstallSite.Value = $true } else { $reInstallSite.Value = $false }
		}
	}
}
function removeDoximApplication
{	
	param
	(
		$coreSiteExists, 
		$silentMode, 
		$sitePath, 
		$siteName, 
		$applicationName
	)
	if (Test-Path $sitePath) 
	{ 
		if (!$coreSiteExists)
		{
			if ($silentMode)
			{
				iisreset | log
			}
			else
			{
				$caption = "Warning! In order to remove existing webSite: "+$siteName+"\"+$applicationName+ " need reset IIS!!"
				$message = "Do you want to reset IIS (all of websites will disconnected during this period)? "
				$result = Get-Choice $caption $message 1
				if($result -eq 0) { iisreset | log } else { break }
			}
		}
	}
	Remove-Application $siteName $applicationName
	if (Test-Path $sitePath) 
	{ 
		$counter = 0
		do  
		{
			Remove-Item $sitePath -recurse -force 
			Start-Sleep -s 1
			$counter = $counter + 1
		}
		while (!$? -OR ($counter -gt 10))
	}
}
function copyDirectorys
{
	param
	(
		$installFolder, 
		$coreSiteExists, 
		$sitePath
	)
	log("####  Copy site directorys")
	if (Test-Path $sitePath) 
	{ 
		log("Remove site folder: $sitePath")
		Remove-Item $sitePath -recurse -force 
	}

	if ($coreSiteExists)
	{
		log("Copy Website only")
		Copy-Item -path (Join-Path $installFolder ECMweb\Website) -destination (Join-Path $sitePath ASP\Website) -recurse -force 
		Copy-Item -path (Join-Path $installFolder ECMweb\Data) -destination (Join-Path $sitePath ASP\Data) -recurse -force 
	}
	else
	{
		log("Copy Website and Lib")
		Copy-Item -path (Join-Path $installFolder ECMweb) -destination (Join-Path $sitePath ASP) -recurse -force 
		Copy-Item -path (Join-Path $installFolder lib) -destination (Join-Path $sitePath lib) -recurse -force 

		registerDll $sitePath
	}
	log("Copy Website DB config file")
	Copy-Item -path (Join-Path (Join-Path $installFolder installer) Doxim.udl) -destination (Join-Path $sitePath ASP\Data\Doxim.udl) -recurse -force 
}
function checkFileStatus($filePath)
{
        $fileInfo = New-Object System.IO.FileInfo $filePath

        try 
        {
            $fileStream = $fileInfo.Open( [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read )
            return $true
        }
        catch
        {
            return $false
        }
}
function registerDll
{
	param
	(
		$sitePath
	)
	#### comment RegisterCom.bat pause
	$batchFilePath = Join-Path (Join-Path $sitePath lib) RegisterCom.bat
	Set-ItemProperty $batchFilePath -name IsReadOnly -value $false	
	$batchFileContent = Get-Content $batchFilePath
	$batchFileContent = $batchFileContent -replace "pause", "REM pause"
	Set-Content $batchFilePath $batchFileContent
	
	log("Run RegisterCom.bat")
	cd (Join-Path $sitePath lib)
	if ($silentMode)
	{
		$stdErrLog = Join-Path $scriptPath "stderr.log"
		$stdOutLog = Join-Path $scriptPath "stdout.log"
		Start-Process $batchFilePath -RedirectStandardOutput $stdOutLog -RedirectStandardError $stdErrLog -NoNewWindow -Wait
		Get-Content $stdErrLog, $stdOutLog | Out-File $Logfile -encoding ASCII -Append
		if (checkFileStatus $stdOutLog) {Remove-Item $stdOutLog -force }
		if (checkFileStatus $stdErrLog) {Remove-Item $stdErrLog -force }
	}
	else
	{
		Start-Process $batchFilePath -NoNewWindow -Wait
	}
	cd $scriptPath
	
	#### uncomment RegisterCom.bat pause
	$batchFileContent = Get-Content $batchFilePath
	$batchFileContent = $batchFileContent -replace "REM pause", "pause"
	#Copy-Item -path (Join-Path (Join-Path $installFolder lib) RegisterCom.bat) -destination $batchFilePath -recurse -force 
}
function configIIS7
{
	param
	(
		$coreApplicationName, 
		$siteName
	)
	log("####  Config IIS7")
	log("Allow Asp.net 4.0")
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config ""/section:isapiCgiRestriction"" ""/[path='$env:windir\Microsoft.NET\Framework\v4.0.30319\aspnet_isapi.dll'].allowed:True"""
	log(Invoke-Expression $appcmd)
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config ""/section:isapiCgiRestriction"" ""/[path='$env:windir\Microsoft.NET\Framework64\v4.0.30319\aspnet_isapi.dll'].allowed:True"""
	log(Invoke-Expression $appcmd)

	log("Enable parent path")
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $siteName + """ ""/section:asp"" ""/enableParentPaths:true"" ""/commit:appHost"""
	log(Invoke-Expression $appcmd)

	log("Remove Custom error page")
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $siteName + """ ""/section:httpErrors"" /-""[statusCode='500', subStatusCode='0']"""
	log(Invoke-Expression $appcmd)
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $siteName + """ ""/section:httpErrors"" /-""[statusCode='500', subStatusCode='100']"""
	log(Invoke-Expression $appcmd)
	
	log("Add Custom error page")
	$errorPagePath = "/" + $coreApplicationName + "/Common/ASPError.asp"
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $siteName + """ ""/section:httpErrors"" /+""[statusCode='500', subStatusCode='0', path='" + $errorPagePath + "', responseMode='ExecuteURL']"""
	log(Invoke-Expression $appcmd)
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $siteName + """ ""/section:httpErrors"" /+""[statusCode='500', subStatusCode='100', path='" + $errorPagePath + "', responseMode='ExecuteURL']"""
	log(Invoke-Expression $appcmd)
	
}
function createApplicationPool
{
	param
	(
		$applicationPoolName, 
		$applicationPoolIdentityDomain, 
		$applicationPoolIdentity, 
		$applicationPoolIdentityPassword
	)
	log("####  Create ApplicationPool")
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe add apppool /name:""" + $applicationPoolName + """ /managedRuntimeVersion:v4.0 /managedPipelineMode:Classic"
	log(Invoke-Expression $appcmd)
	log("Set ApplicationPool Identity")
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config /section:applicationPools " + """/[name='" + $applicationPoolName + "'].processModel.identityType:SpecificUser"" " + """/[name='" + $applicationPoolName + "'].processModel.userName:" + (Join-Path $applicationPoolIdentityDomain $applicationPoolIdentity) + """ " + """/[name='" + $applicationPoolName + "'].processModel.password:" + $applicationPoolIdentityPassword + """"
	log(Invoke-Expression $appcmd)
	log("Enable 32-Bit Applications")
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set apppool /apppool.name:""" + $applicationPoolName + """ ""/enable32BitAppOnWin64:true"""
	log(Invoke-Expression $appcmd)
}
function createApplication
{
	param
	(
		$siteName, 
		$sitePath, 
		$applicationName, 
		$applicationPoolName
	)
	log("####  Create Application under site")
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe add app /site.name:""" + $siteName + """ /path:/" + $applicationName +" /physicalPath:""" + (Join-Path $sitePath "Asp\Website") + """"
	log(Invoke-Expression $appcmd)
	log("Set Application's application pool")
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set app /app.name:""" + $siteName + "/" + $applicationName + """ /applicationPool:""" + $applicationPoolName + """"
	log(Invoke-Expression $appcmd)
}
function createVirualDirectory
{
	param
	(
		$coreAdminParentPath, 
		$siteName, 
		$applicationName
	)
	log("####  Create Virtual Directory Admin, Web, Common")
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe add vdir /app.name:""" + $siteName + "/" + $applicationName + """ /path:/Admin /physicalPath:""" + (Join-Path $coreAdminParentPath "Admin") + """"
	log(Invoke-Expression $appcmd)
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe add vdir /app.name:""" + $siteName + "/" + $applicationName + """ /path:/Web /physicalPath:""" + (Join-Path $coreAdminParentPath "Web") + """"
	log(Invoke-Expression $appcmd)
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe add vdir /app.name:""" + $siteName + "/" + $applicationName + """ /path:/Common /physicalPath:""" + (Join-Path $coreAdminParentPath "Common") + """"
	log(Invoke-Expression $appcmd)
}
function configApplication
{
	param
	(
		$siteName, 
		$applicationName, 
		$applicationPoolIdentityDomain, 
		$applicationPoolIdentity, 
		$applicationPoolIdentityPassword
	)
	log("####  Config Application")
	log("Set site authentication")
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $siteName + "/" + $applicationName + """ ""/section:anonymousAuthentication"" ""/userName:" + (Join-Path $applicationPoolIdentityDomain $applicationPoolIdentity) + """ ""/password:" + $applicationPoolIdentityPassword + """ ""/commit:apphost"""
	log(Invoke-Expression $appcmd)
	log("Set site default page")
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set unlock config """ + $siteName + "/" + $applicationName + """ ""/section:aspdefaultDocument"""
	log(Invoke-Expression $appcmd)
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $siteName + "/" + $applicationName + """ ""/section:defaultDocument"" ""/+files.[value='default.htm']"""
	log(Invoke-Expression $appcmd)
	log("Send Errors to browser")
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $siteName + "/" + $applicationName + """ /section:system.webServer/asp /scriptErrorSentToBrowser:""True"""
	log(Invoke-Expression $appcmd)
	log("Set Request filtering")
	$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $siteName + "/" + $applicationName + """ /section:requestfiltering /requestlimits.maxallowedcontentlength:60000000"
	log(Invoke-Expression $appcmd)
}
function updateConnectionString
{
	param
	(
		$sitePath, 
		$serverName, 
		$dbName, 
		$userId, 
		$password
	)
	log("####  Modify Doxim.udl")
	$dbFilePath = Join-Path $sitePath ASP\Data\Doxim.udl
	Set-ItemProperty $dbFilePath -name IsReadOnly -value $false	
	$dbFile = Get-Content $dbFilePath
	$dbFile = $dbFile -replace "DBSRVR", $serverName
	$dbFile = $dbFile -replace "SQLDBNAME", $dbName
	$dbFile = $dbFile -replace "SQLUSERNAME", $userId
	$dbFile = $dbFile -replace "SQLPASSWORD", $password
	Set-Content $dbFilePath $dbFile -Encoding Unicode
	Set-ItemProperty $dbFilePath -name IsReadOnly -value $true	
}
function cleanUp
{
	param
	(
		$sitePath
	)
	log("del web.config")
	$webConfigPath = Join-Path $sitePath ASP\Website\web.config
	if (Test-Path $webConfigPath) 
	{
		Remove-Item $webConfigPath -recurse -force 
	}
}
$global:InstallSuccess = $true
[xml]$cfgFile = Get-Content $configFile 
$cfg = $cfgFile.configuration.site
$coreSiteExists = [boolean]::Parse($cfg.coreSite.exists)
$coreApplicationName = if ($coreSiteExists) {$cfg.coreSite.applicationName } else {$cfg.WebSite.applicationName}
$coreAdminParentPath = if ($coreSiteExists) {$cfg.coreSite.adminParentPath } else {Join-Path $cfg.webSite.path "Asp"}
$poolExists = Test-Path ("IIS:\AppPools\"+$cfg.webSite.applicationPool)
$siteExists = Test-Path ("IIS:\Sites\"+$cfg.WebSite.siteName+"\"+$cfg.WebSite.applicationName)
$reInstallPool = $false
$reInstallSite = $false
$silentMode = !($applicationPoolIdentityPassword -eq "" -OR $dBServerPassword -eq "") 

Import-Module (Join-Path $scriptPath "doximSite") -ArgumentList @($Logfile, $silentMode)

If (Test-Path $Logfile)
{
	Clear-Content $Logfile
}	
log("Start at: {0} {1}" -f (Get-Date).ToLongDateString(), (Get-Date).ToLongTimeString() )
checkPrerequisites
if ($global:InstallSuccess)
{		
	$silentModeStr = if($silentMode) {"Silent"} else {"Interactive"}
	log("Install Site: {0} (CoreSite:{1}) in {2} Mode" -f (Join-Path $cfg.webSite.siteName $cfg.webSite.applicationName), !$coreSiteExists, $silentModeStr )
	checkExistingPool $poolExists $silentMode ([ref]$reInstallPool)
	checkExistingSite $siteExists $silentMode ([ref]$reInstallSite)

	if ($siteExists -and $reInstallSite)
	{
		log("Remove existing site: {0}" -f (Join-Path $cfg.webSite.siteName $cfg.webSite.applicationName) )
		removeDoximApplication $coreSiteExists $silentMode $cfg.webSite.path $cfg.webSite.siteName $cfg.webSite.applicationName
		if ($poolExists -and $reInstallPool) 
		{ 
			log("Remove existing application pool: {0}" -f $cfg.webSite.applicationPool )
			Remove-ApplicationPool $cfg.webSite.applicationPool 
		}
	}
	if (!$siteExists -or $reInstallSite)
	{
		if (!$silentMode)
		{
			log("Get password from console")
			$domainUserId = Join-Path $cfg.webSite.applicationPoolIdentityDomain $cfg.webSite.applicationPoolIdentity
			$applicationPoolIdentityPassword = Get-Password "What is the password for domain user: $domainUserId ?"
			$dBServerPassword = Get-Password ("What is database password for user: {0} ?" -f $cfg.dBServer.userId)
		}
		
		copyDirectorys $InstallFolder $coreSiteExists $cfg.webSite.path
		configIIS7 $coreApplicationName, $cfg.webSite.siteName
		createApplicationPool $cfg.webSite.applicationPool $cfg.webSite.applicationPoolIdentityDomain $cfg.webSite.applicationPoolIdentity $applicationPoolIdentityPassword
		createApplication $cfg.webSite.siteName $cfg.webSite.path $cfg.webSite.applicationName $cfg.webSite.applicationPool
		createVirualDirectory $coreAdminParentPath $cfg.webSite.siteName $cfg.webSite.applicationName
		configApplication $cfg.webSite.siteName $cfg.webSite.applicationName $cfg.webSite.applicationPoolIdentityDomain $cfg.webSite.applicationPoolIdentity $applicationPoolIdentityPassword
		updateConnectionString $cfg.webSite.path $cfg.dBServer.serverName $cfg.dBServer.dbName $cfg.dBServer.userId $dBServerPassword
		cleanUp $cfg.webSite.path 
		log("Doxim ECM Site: {0}/{1} Complete Installed" -f $cfg.webSite.siteName,$cfg.webSite.applicationName) | Write-Host -ForegroundColor "Green"
	}
	else
	{
		$global:InstallSuccess = $false
		log("Found Previous Doxim ECM Site: {0}/{1} " -f $cfg.webSite.siteName,$cfg.webSite.applicationName) | Write-Host -ForegroundColor "Yellow"
		exit 2
	}
	log("End at: {0} {1}" -f (Get-Date).ToLongDateString(), (Get-Date).ToLongTimeString())
	exit 3
	return $global:InstallSuccess
	
}
else
{
	exit 4
	return $global:InstallSuccess
}

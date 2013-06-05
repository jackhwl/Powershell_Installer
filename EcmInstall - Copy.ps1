param(
[string]$IN_BEPLOY_POWERSHELL_CONFIG_FILE = "ConfigFile.xml",
[string]$IN_BEPLOY_SCRIPT   = "\\Deploy Script Folder",
[string]$IN_INSTALL_FOLDER   = "\\INSTALL WEBSITE Folder",
[string]$IN_SOURCE_CODE     = "\\Source Code Folder",
[string]$IN_BINARY           = "\\Build Folder",
[string]$IN_DB              = "\\DB Folder",
[string]$IN_DB_SCRIPT       = "\\DB Script Folder",
[string]$IN_DOCUMENT        = "\\Document Folder",
[string]$IN_WHO_FIRES_DEPLOY = "\\Who Started this Deploy")

#***********************************************************************
#************************* Sub Function Import *************************
#***********************************************************************
Import-Module bpmFunction

$dt = Get-Date
$date = "Deploy Date: " + $dt.ToShortDateString() + "<br />"
$time = "Deploy Time: " + $dt.ToShortTimeString() + "<br />"

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

#***********************************************************************
#***************** Read config from configFile.xml  ********************
#***********************************************************************
$global:msg = ""
$global:line = 0
$global:DEPLOY_STATUS = "SUCCESS"

try{
	[xml]$c = Get-Content $IN_BEPLOY_POWERSHELL_CONFIG_FILE 
	$serverName   = $c.Configuration.DeployServer.ServerName 	
	$database = $c.Configuration.DeployServer.databasename 
	$username = $c.Configuration.DeployServer.databaseusername 
	$password = $c.Configuration.DeployServer.databasepassword
	$global:DEPLOY_FOLDER = $c.Configuration.DeployServer.DEPLOY_FOLDER
	$global:INSTALL_FOLDER = $c.Configuration.DeployServer.INSTALL_FOLDER
}catch{
	$DEPLOY_STATUS = "FAIL" 
	$msg = $msg + "File open ERROR " + $_
}
#***********************************************************************
#*********************  MACRO Replace Operation	************************
#***********************************************************************
function ReplacePath($path) {
				  $tempPath = $path
				  $tempPath = $tempPath -replace "DEPLOY_FOLDER", $global:DEPLOY_FOLDER
				  $tempPath = $tempPath -replace "INSTALL_FOLDER", $global:INSTALL_FOLDER
				  $tempPath = $tempPath -replace "TFS_BINARY_FOLDER", $IN_BINARY
				  $tempPath = $tempPath -replace "TFS_SOURCE_FOLDER", $IN_SOURCE_CODE
				  $tempPath = $tempPath -replace "TFS_DB_FOLDER", $IN_DB
				  $tempPath = $tempPath -replace "TFS_DB_SCRIPT_FOLDER", $IN_DB_SCRIPT
				  $tempPath = $tempPath -replace "TFS_DEPLOY_SCRIPT_FOLDER", $IN_BEPLOY_SCRIPT
				  return $tempPath
}
function log($logMsg) {
				  $global:line++
				  $global:msg = $global:msg + $global:line + " "+  $logMsg + "<br />"
				  #Write-host "logMsg msg = " $logMsg  "`n"
				  if ($global:msg.Contains("ERROR") -or $global:msg.Contains("Cannot find")){
					$global:DEPLOY_STATUS = "FAIL"					 
				  }
				  return $global:msg
}
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
#***********************************************************************
#*******************  Deploy: Do it one by one	************************
#***********************************************************************
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""
$choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes,$no)

$global:msg = "Deploy Server: " + $serverName + "<br />"
$global:msg = $global:msg + "Deploy Folder: " + $global:DEPLOY_FOLDER + "<br />"
$global:msg = $global:msg + "Requested by: " + $IN_WHO_FIRES_DEPLOY + "<br />"
$global:msg = $global:msg + $date
$global:msg = $global:msg + $time

try{
	foreach ($d in $c.Configuration.Deploy)
	{
		if ($global:DEPLOY_STATUS -eq "SUCCESS"){	
			switch ($d.type)
			{
				"website" {
                        #    <File action="delete"   wait="2" Name="INSTALL_FOLDER"></File>
						#	<File action="copy"   wait="5" From="DEPLOY_FOLDER\web\Website" To="INSTALL_FOLDER\ASP\Website"></File>
						#	<File action="copy"   wait="2" From="DEPLOY_FOLDER\web\Admin" To="INSTALL_FOLDER\ASP\Admin"></File>
						#	<File action="copy"   wait="2" From="DEPLOY_FOLDER\web\Common" To="INSTALL_FOLDER\ASP\Common"></File>
						#	<File action="copy"   wait="2" From="DEPLOY_FOLDER\web\Web" To="INSTALL_FOLDER\ASP\Web"></File>
				# <WebSite siteName="Default Web Site" applicationName="Doxim72" applicationPool="DoximEDoc72" applicationPoolIdentityDomain="Research" 
				# applicationPoolIdentity="ECMService" applicationPoolIdentityPwd="horton" 
				# path="\\RVJACKH\installer\PowerShell\Website2" />
				
				
						#appcmd set config /section:requestfiltering /requestlimits.maxallowedcontentlength:30000000
						#$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $d.WebSite.siteName + "/" + $d.WebSite.applicationName + """ /section:requestfiltering /requestlimits.maxallowedcontentlength:60000000"
						#echo $appcmd
						#Invoke-Expression $appcmd
						$reInstallPool = $false
						$reInstallSite = $false
						if (Test-Path ("IIS:\AppPools\"+$d.WebSite.applicationPool))
						{
							$caption = "Warning! applicationPool: "+$d.WebSite.applicationPool+" already exists!!"
							$message = "Do you want to remove this applicationPool and reinstall a new one? "
							$result = $Host.UI.PromptForChoice($caption,$message,$choices,1)
							if($result -eq 0) { $reInstallPool = $true }
						}
						if (Test-Path ("IIS:\Sites\"+$d.WebSite.siteName+"\"+$d.WebSite.applicationName))
						{
							$caption = "Warning! WebSite: "+$d.WebSite.siteName+"\"+$d.WebSite.applicationName+ " already exists!!"
							$message = "Do you want to remove this site and reinstall a new one? "
							$result = $Host.UI.PromptForChoice($caption,$message,$choices,1)
							if($result -eq 0) { $reInstallSite = $true }
						}

						##### Check Install Prerequisites	
						if ([string](Get-Framework-Versions).IndexOf("4.0") -lt 0)
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

						if (Test-Path $d.WebSite.path)
						{	
							Remove-Item $d.WebSite.path -recurse -force 
						}
						$coreSiteExists = [boolean]::Parse($d.CoreSite.exists)
						$coreApplicationName = $d.CoreSite.applicationName 
						$coreAdminParentPath = if ($coreSiteExists) {$d.CoreSite.adminParentPath } else {Join-Path $d.WebSite.path "Asp"}
						if ($coreSiteExists)
						{
							echo "#####      Copy Website only"
							Copy-Item -path (Join-Path $global:DEPLOY_FOLDER web\Website) -destination (Join-Path $d.WebSite.path ASP\Website) -recurse -force 
							Copy-Item -path (Join-Path $global:DEPLOY_FOLDER web\Data) -destination (Join-Path $d.WebSite.path ASP\Data) -recurse -force 
						}
						else
						{
							echo "#####      Copy Website and Lib"
							Copy-Item -path (Join-Path $global:DEPLOY_FOLDER web) -destination (Join-Path $d.WebSite.path ASP) -recurse -force 
							Copy-Item -path (Join-Path $global:DEPLOY_FOLDER lib) -destination (Join-Path $d.WebSite.path lib) -recurse -force 
							
							#### comment RegisterCom.bat pause
							$batchFilePath = Join-Path (Join-Path $d.WebSite.path lib) RegisterCom.bat
							$batchFileContent = Get-Content $batchFilePath
							$batchFileContent = $batchFileContent -replace "pause", "REM pause"
							Set-Content $batchFilePath $batchFileContent
							
							echo "#####      Run RegisterCom.bat"
							Start-Process $batchFilePath -NoNewWindow -Wait

							#### uncomment RegisterCom.bat pause
							$batchFileContent = Get-Content $batchFilePath
							$batchFileContent = $batchFileContent -replace "REM pause", "pause"
							Set-Content $batchFilePath $batchFileContent
							
							echo "#####      Add Custom error page"
							$errorPagePath = "/" + $coreApplicationName + "/Common/ASPError.asp"
							$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $d.WebSite.siteName + """ ""/section:httpErrors"" /+""[statusCode='500', subStatusCode='0', path='" + $errorPagePath + "', responseMode='ExecuteURL']"""
							Invoke-Expression $appcmd
							$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $d.WebSite.siteName + """ ""/section:httpErrors"" /+""[statusCode='500', subStatusCode='100', path='" + $errorPagePath + "', responseMode='ExecuteURL']"""
							Invoke-Expression $appcmd
						}

						echo "#####      Modify Doxim.udl"
						$dbFile = Get-Content (Join-Path $d.WebSite.path ASP\Data\Doxim.udl)
						$dbFile = $dbFile -replace "DBSRVR", $serverName
						$dbFile = $dbFile -replace "SQLDBNAME", $database
						$dbFile = $dbFile -replace "SQLUSERNAME", $username
						$dbFile = $dbFile -replace "SQLPASSWORD", $password
						Set-Content (Join-Path $d.WebSite.path ASP\Data\Doxim.udl) $dbFile
						
						echo "#####      Allow Asp.net 4.0"
						$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config ""/section:isapiCgiRestriction"" ""/[path='$env:windir\Microsoft.NET\Framework\v4.0.30319\aspnet_isapi.dll'].allowed:True"""
						Invoke-Expression $appcmd
						$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config ""/section:isapiCgiRestriction"" ""/[path='$env:windir\Microsoft.NET\Framework64\v4.0.30319\aspnet_isapi.dll'].allowed:True"""
						Invoke-Expression $appcmd

						echo "#####      Enable parent path"
						$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $d.WebSite.siteName + """ ""/section:asp"" ""/enableParentPaths:true"""
						Invoke-Expression $appcmd

						echo "#####      Create ApplicationPool"
						$appcmd = "$env:windir\system32\inetsrv\appcmd.exe add apppool /name:""" + $d.WebSite.applicationPool + """ /managedRuntimeVersion:v4.0 /managedPipelineMode:Classic"
						Invoke-Expression $appcmd
						echo "#####      Set ApplicationPool Identity"
						$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config /section:applicationPools " + """/[name='" + $d.WebSite.applicationPool + "'].processModel.identityType:SpecificUser"" " + """/[name='" + $d.WebSite.applicationPool + "'].processModel.userName:" + (Join-Path $d.WebSite.applicationPoolIdentityDomain $d.WebSite.applicationPoolIdentity) + """ " + """/[name='" + $d.WebSite.applicationPool + "'].processModel.password:" + $d.WebSite.applicationPoolIdentityPwd + """"
						Invoke-Expression $appcmd
						echo "#####      Enable 32-Bit Applications"
						$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set apppool /apppool.name:""" + $d.WebSite.applicationPool + """ ""/enable32BitAppOnWin64:true"""
						Invoke-Expression $appcmd
						echo "#####      Create Application under site"
						$appcmd = "$env:windir\system32\inetsrv\appcmd.exe add app /site.name:""" + $d.WebSite.siteName + """ /path:/" + $d.WebSite.applicationName +" /physicalPath:""" + (Join-Path $d.WebSite.path "Asp\Website") + """"
						Invoke-Expression $appcmd
						echo "#####      Set Application's application pool"
						$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set app /app.name:""" + $d.WebSite.siteName + "/" + $d.WebSite.applicationName + """ /applicationPool:""" + $d.WebSite.applicationPool + """"
						Invoke-Expression $appcmd
						
						echo "#####      Create Virtual Directory Admin, Web, Common"
						$appcmd = "$env:windir\system32\inetsrv\appcmd.exe add vdir /app.name:""" + $d.WebSite.siteName + "/" + $d.WebSite.applicationName + """ /path:/Admin /physicalPath:""" + (Join-Path $coreAdminParentPath "Admin") + """"
						Invoke-Expression $appcmd
						$appcmd = "$env:windir\system32\inetsrv\appcmd.exe add vdir /app.name:""" + $d.WebSite.siteName + "/" + $d.WebSite.applicationName + """ /path:/Web /physicalPath:""" + (Join-Path $coreAdminParentPath "Web") + """"
						Invoke-Expression $appcmd
						$appcmd = "$env:windir\system32\inetsrv\appcmd.exe add vdir /app.name:""" + $d.WebSite.siteName + "/" + $d.WebSite.applicationName + """ /path:/Common /physicalPath:""" + (Join-Path $coreAdminParentPath "Common") + """"
						Invoke-Expression $appcmd
						
						echo "#####      Set site default page"
						$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $d.WebSite.siteName + "/" + $d.WebSite.applicationName + """ ""/section:defaultDocument"" ""/+files.[value='default.htm']"""
						Invoke-Expression $appcmd
						echo "#####      Send Errors to browser"
						$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $d.WebSite.siteName + "/" + $d.WebSite.applicationName + """ /section:system.webServer/asp /scriptErrorSentToBrowser:""True"""
						Invoke-Expression $appcmd
						echo "#####      Set Request filtering"
						$appcmd = "$env:windir\system32\inetsrv\appcmd.exe set config """ + $d.WebSite.siteName + "/" + $d.WebSite.applicationName + """ /section:requestfiltering /requestlimits.maxallowedcontentlength:60000000"
						Invoke-Expression $appcmd

						#$frenchPack = Get-WmiObject -Class Win32_Product | Where {$_.Name -match 'Microsoft .NET Framework 4 Extended FRA Language Pack' }
						#if ($frenchPack -eq $NULL) { 
						#	echo "#####      Install .NetFramwork4 french language pack"
						#	$frenLangPackPath = Join-Path (Join-Path $global:DEPLOY_FOLDER installer) dotNetFx40LP_Full_x86_x64fr.exe
						#	Start-Process $frenLangPackPath -Wait
						#} 
						


						### return the path of the share named 'shared"
						### $tphy = (Get-WmiObject Win32_Share -filter "Name LIKE '\\RVJACKH\installer\PowerShell\Website2\Asp\Website'").path 
						### echo $tphy
				}
				"file" {
						foreach ($f in $d.File){
							switch ($f.action){
								"delete"{
										log("File[delete] " + (ReplacePath $f.Name) + "  wait  " + $f.wait)									
										Remove-Item (ReplacePath $f.Name) -recurse -force
										Start-Sleep -s $f.wait							
										}
								"rename"{
										log("File[rename] from " + (ReplacePath $f.From) + " to " + (ReplacePath $f.To) + "  wait  " + $f.wait)												
										Rename-Item (ReplacePath $f.From)  (ReplacePath $f.To)
										Start-Sleep -s $f.wait							
										}
								"copy"  {
										log("File[copy] from " + (ReplacePath $f.From) + " to " + (ReplacePath $f.To) + "  wait  " + $f.wait)															
										#Copy-Item (ReplacePath $f.From) (ReplacePath $f.To) -recurse							
										Copy-Item -path (ReplacePath $f.From) -destination (ReplacePath $f.To) -recurse -force 
										}
								default {
										log("ERROR: File Action $f.action is not defined!")	
										break
										}
							}
						}
				}
				"dbscript" {
							foreach ($sc in $d.Script){
									try{
										log( "Script[dbscript] script name" + $sc.Name)										
										$sql_file = ReplacePath $sc.Name 										
										log( "Script[dbscript] sql file name" + $sql_file)
										Invoke-Sqlcmd -inputfile $sql_file -ServerInstance $serverName -database $database -QueryTimeout 65535 -ErrorAction 'Stop' -username $username -password $password		
										Start-Sleep -s $sc.wait
									}catch{
										log("ERROR: Script[dbscript][$sql_file] when running databaserestore" +  "<br />" + $_)
										#Write-Host($error)
										break
									}
							}
				}
				"dbupgradescript"{
								try{
									foreach ($m_script in $d.upgradescripts.masterfilename){
										log("Script[dbupgradescript] Master Script = " + $m_script)
										$sql_masterScript = ReplacePath $m_script
										log( "Script[dbupgradescript] Master Script (full path)= " + $sql_masterScript)
										foreach( $m_db in $d.databases.masterdbname ){
											log( "Script[dbupgradescript] Master DB     = " + $m_db)
											Invoke-Sqlcmd -inputfile $sql_masterScript -ServerInstance $serverName -database $m_db -QueryTimeout 65535 -ErrorAction 'Stop' -username $username -password $password		
											Start-Sleep -s 3	
											log( "Script[dbupgradescript] Master DB ok  = " + $m_db + " <- " + $sql_masterScript )
										}
									}		
								}catch{
									log("ERROR: Script[dbscript][$sql_masterScript] on [$m_db] when running sql_master" + "<br />"  + $_)
									#Write-Host($error)
									break
								}

								try{
									foreach ($c_script in $d.upgradescripts.cufilename){
										log( "Script[dbupgradescript] @CU Script     = " + $c_script)
										$sql_cuScript = ReplacePath $c_script
										log( "Script[dbupgradescript] @CU Script (full path)= " + $sql_cuScript)		
										foreach( $c_db in $d.databases.cudbname ){
											#log(  "Script[dbupgradescript] @CU DB         = " + $c_db)
											Invoke-Sqlcmd -inputfile $sql_cuScript -ServerInstance $serverName -database $c_db -QueryTimeout 65535 -ErrorAction 'Stop' -username $username -password $password
											Start-Sleep -s 3
											log( "Script[dbupgradescript] @CU DB    ok   = " + $c_db + " <- " + $sql_cuScript)
										}
									}
								}catch{
									log("ERROR: Script[dbupgradescript][$sql_cuScript] on [$c_db] when running sql_cu" + "<br />"  + $_)
									#Write-Host($error)
									break
								}
								log("Script[dbupgradescript] @@@@@FINISHED@@@@@. Bravo~~~")
				}
				"service"{
						foreach ($svc in $d.Service){
							switch ($svc.action){
								"stop" {
										log( "Service[stop]  " + $svc.name + " wait "+ $svc.wait)
										$SQLservice = Get-Service -ComputerName $serverName | Where-Object {$_.Name -eq $svc.name} 
										Stop-Service -InputObject $SQLservice -Force
										Start-Sleep -s $svc.wait								
										}
								"start"{
										log( "Service[start] " + $svc.name + " wait "+ $svc.wait)
										$SQLservice = Get-Service -ComputerName $serverName | Where-Object {$_.Name -eq $svc.name} 
										Start-Service -InputObject $SQLservice
										Start-Sleep -s $svc.wait
								}
								default{
									log("ERROR: Service Action $svc.action is not defined!"+ "<br />"  + $_)
									break
								}
							}
						}
				}
			    "batchfile"{
						foreach ($bf in $d.BatchFile){
								$batch_file = ReplacePath $bf.FileName								
								log( "BatchFile  " + $batch_file + " wait "+ $bf.wait)
								$server = $serverName
								$process = [WMICLASS]"\\$server\ROOT\CIMV2:win32_process"  
								$result = $process.Create("$batch_file") 
								if ($result.ReturnValue -eq 0)
								{
									log("Successfully stated " + $batch_file)
								}
								else
								{
									log("ERROR: Fail to start " + $batch_file + "<br />" )
								}								
								Start-Sleep -s $bf.wait
						}
				}
				"queuebuild"{
						foreach ($qb in $d.Build){
							log( "Queue Build in project [" + $qb.ProjectName + "], build definition [" + $qb.DefinitionName + "] wait "+ $qb.wait)
							$TFSserverName = "http://rstfs:8080/tfs"
							[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Client")
							[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Build.Client")
							$TFS = [Microsoft.TeamFoundation.Client.TeamFoundationServerFactory]::GetServer($TFSserverName)
							$TFSService = $TFS.GetService([Microsoft.TeamFoundation.Build.Client.IBuildServer])							
							$BuildDefination = $TFSService.GetBuildDefinition($qb.ProjectName, $qb.DefinitionName)
							$BuildRequest = $BuildDefination.CreateBuildRequest()
							$TFSService.QueueBuild($BuildRequest,"None")
							Start-Sleep -s $qb.wait								
						}
				}
				default {
				    log("ERROR: Deploy TYPE $d.type is not defined!" + "<br />" + $_)
				}
			}
	   }
	}
}catch{
	$global:DEPLOY_STATUS = "FAIL"
	$global:msg = $global:msg + "<br />"  + $_ + "<br />" 
	#Write-host $global:msg
}
<#
Write-host "-------------------------end then send e mail-------------------------------"

$EmailFrom = "AutoBuild@doxim.com"
$EmailTo = "jhuang@doxim.com"
$EmailSubject = $global:DEPLOY_STATUS + " ECM 7.2 Build on RsAutoTest Server"
$EmailBody = $global:msg
  
$SMTPServer = "mail2.doxim.com"
$SMTPAuthUsername = "jhuang@doxim.com"
$SMTPAuthPassword = "jackhwl15"

$MailMessage = New-Object system.net.mail.mailmessage 
$MailMessage.From = ($EmailFrom) 
$MailMessage.To.add($EmailTo)
$MailMessage.Subject = $EmailSubject
$MailMessage.Body = $EmailBody

$MailMessage.IsBodyHTML = $true
$SMTPClient = New-Object System.Net.Mail.SmtpClient($SmtpServer, 25)  
$SMTPClient.Credentials = New-Object System.Net.NetworkCredential("$SMTPAuthUsername", "$SMTPAuthPassword")
$SMTPClient.Send($MailMessage)
Write-host "global:msg==" $global:msg

#>
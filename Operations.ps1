
<# 

This script is for environment management and deployment purposes
by Pinega F.V. on july 2023

#>

param(

[string] $transactionId='',
[string] $customWokingFolder='',
[string] $callType='plain' # plain, external-from-self,  external-from-other-script
)

<# 
$userName0 = "root";
$pwd0 = ConvertTo-SecureString "4*cXVNAmP|gy" -AsPlainText -Force
$deployCreds0 = New-Object System.Management.Automation.PSCredential ($userName0, $pwd0)

$userName1 = "root01";
$pwd1 = ConvertTo-SecureString "64pVSprEtQ" -AsPlainText -Force
$deployCreds1 = New-Object System.Management.Automation.PSCredential ($userName1, $pwd1)
 #>


#COMMON
[string] $scriptDir = $PSScriptRoot;
[string] $scriptFile=$MyInvocation.MyCommand;
[string] $scriptFileFullPath = [IO.Path]::Combine($scriptDir,$scriptFile);
[string] $pwshPath = "C:\Program Files\PowerShell\7\pwsh.exe";
[string] $operaExeFullPath = "C:\Users\Admin\AppData\Local\Programs\Opera\opera.exe"

#COMMON -- MENUMAKER
[string] $menuFileName='MenuDetail.txt';
[string] $menuFileFullPath=[IO.Path]::Combine($scriptDir,$menuFileName);

[string] $currentLogFileName = '';
[string] $logFileFullPath='';
[string] $logsDirectory=[IO.Path]::Combine($scriptDir,'Logs');
[int]    $howManyLogFilesToLeaveInLogsDirectory = 3
[bool] $canExit=$false;

# CREDS AND LOGIN DATA
    # file to store creds in
[string] $credsFilePath = "C:\Develop\Deploy\Creds\Creds.txt";
[string] $deployAddress01='';
[string] $deployHost01='';

$menuContent = Get-content $menuFileFullPath



function PerformCls()
{
   #  Clear-host
}

function ShowMenu() {
    ""
    ""
    "MAIN MENU"
    $menuContent
    "99-Exit"
}

# setup TrustedHosts
if($transactionId -eq '')
{
   
    # if ($tth -ne $tth_fact)    {        Set-Item WSMan:\localhost\Client\TrustedHosts -Value $tth -Force;    }
    
    $tth = '31.31.42.42';
    $x0 = Set-Item WSMan:\localhost\Client\TrustedHosts -Value $tth -Force;
    $tth_fact = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value;
    
    #Set-Item -Path  WSMan:\localhost\Service\AllowEncrypted -Value $true;
}

function Pressenter ()
{
    Read-Host -Prompt 'Press enter...'
}

function SetupCredentials()
{
    [string] $fileData = "";
    
    [bool] $credFileExists= [System.IO.File]::Exists($credsFilePath);
    
    if (-not $credFileExists) {return;}

    $fileData =  [System.IO.File]::ReadAllText($credsFilePath);
    log "fileData=$($fileData)"
    $arr=$fileData.Split("`n");

    log "arr.Length=$($arr.Length)"

    if($arr.Length -gt 0)
    {
        $script:deployAddress01 = GetValueFromArray -arr $arr -key 'DeployAddress01' | Select-Object  -Last 1
        $script:deployHost01 = GetValueFromArray -arr $arr -key 'DeployHost01' | Select-Object  -Last 1
    }

    Log "deployAddress01=$deployAddress01"
}

function GetValueFromArray($arr, [string]$key)
{
    [string] $found = $arr | Where-Object { $_.Contains($key) }  | Select-Object  -Last 1
    if($null -eq $found) {"";return;}
    ($found.Split(" ")[1]).Trim();
}

function Log ([string] $text)
{
    if ($script:currentLogFileName -eq '')
    {
        [string]$dtVar = Get-Date -Format "dd-MM-yyyy_HH-mm-ss"
        if($transactionId -eq '') {$tr=''} else {$tr="_$transactionId"}
        $script:currentLogFileName = "$($dtVar)$($tr).txt"
    }
    $Script:logFileFullPath = [IO.Path]::Combine($logsDirectory, $script:currentLogFileName)
    if ([System.IO.File]::Exists($Script:logFileFullPath)){}else{New-Item $Script:logFileFullPath | Out-Null}
    "[$(Get-Date -Format "dd.MM.yyyy-HH:mm:ss")] $text" | Add-Content $Script:logFileFullPath;
}

#COMMON FUNCTION
function CheckLogsDirectory()
{
    CreateDirectoryOnLocalHostIfNotExists -directoryName $logsDirectory
}

function CLearLogs()
{
    KeepOnlyNLastFilesInDirectory -directory $logsDirectory -itemsCol $howManyLogFilesToLeaveInLogsDirectory
}

function CreateDirectoryOnLocalHostIfNotExists([string] $directoryName)
{
    if (-not (Test-Path $directoryName -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $directoryName
    } 
}
function PerformTimeSpanFormat([timespan] $ts)
{
    if ($ts.TotalMilliseconds -gt 86400000)
    {
        "{0:dd}:{0:hh}:{0:mm}:{0:ss}" -f $ts
    }
    else 
    {
        "{0:hh}:{0:mm}:{0:ss}" -f $ts
    }
}

function KeepOnlyNLastFilesInDirectory([string] $directory, [int] $itemsCol)
{
    if (-not (Test-path -Path $directory)) {return};
    Get-ChildItem $directory | Sort-Object CreationTime | Select-Object -SkipLast $itemsCol | Remove-Item -Force -Recurse
}

function PerformSecondsCountDown ([int] $seconds, [string]$prefix="Performing countdown", [bool] $performLog=$false)
{
    [datetime] $currentTime= Get-Date;
    [datetime] $targetTime= $currentTime.AddSeconds($seconds);
    [bool] $flag=$true;
    DO
    {
        $currentTime= Get-Date;
        $delta = $targetTime - $currentTime;

            if($flag) 
            {
                [string] $ts= PerformTimeSpanFormat -ts $delta
                write-host "`r$($prefix): $ts"
                if($performLog)
                {
                    Log -text "Performing countdown log, its $ts left"
                }
                $flag = $false;
            }
            else
            {
                $flag=$true;            
            }

        Start-Sleep -Milliseconds 500
    }
    WHILE ($delta.TotalMilliseconds -ge 0)
}

#CORE CONTENT

function DeployStore01 ([string] $_transactionId)
{
    if($callType -eq 'plain')
    {
        # this is made to start transaction in a separate window
        [string] $argList = "-file $scriptFileFullPath -transactionId $_transactionId -callType 'external-from-self' ";
        Start-process -FilePath $pwshPath -ArgumentList $argList -PassThru;
        return;
    }
    
    [string] $remoteFolder = "/var/www/www-root/data/www/store01.t109.tech";
    [string] $projectPath =      "C:\Develop\T109ActivityFrontendFirstSampleVersion\Shop\T109.ActiveDive.FrontEnd.Blazor";
    [string] $projectBuildPath = "C:\Develop\Deploy\BalzorDeployFolder";
    [string] $siteUrl = "https://store01.t109.tech";

    DeployBalzorWasm60SiteToUbuntuHost -remoteFolder $remoteFolder -projectPath $projectPath -projectBuildPath $projectBuildPath -siteUrl $siteUrl

}



function DeployApi01 ([string] $_transactionId)
{
    if($callType -eq 'plain')
    {
        # this is made to start transaction in a separate window
        [string] $argList = "-file $scriptFileFullPath -transactionId $_transactionId -callType 'external-from-self' ";
        Start-process -FilePath $pwshPath -ArgumentList $argList -PassThru;
        return;
    }
    
    [string] $remoteFolder = "/var/www/www-root/data/www/storeapi01.t109.tech";
    [string] $projectPath = "C:\Develop\T109ActivityFrontendFirstSampleVersion\Shop\T109.ActiveDive.EventCatalogue.EventCatalogueApi";
    [string] $projectBuildPath = "C:\Develop\T109ActivityFrontendFirstSampleVersion\Shop\T109.ActiveDive.EventCatalogue.EventCatalogueApi\bin\Release\net6.0\*";
    [string] $wwwRootFolder =    "C:\Develop\T109ActivityFrontendFirstSampleVersion\Shop\T109.ActiveDive.EventCatalogue.EventCatalogueApi\wwwroot";
    [string] $executingFileFullPath = "/var/www/www-root/data/www/storeapi01.t109.tech/T109.ActiveDive.EventCatalogue.EventCatalogueApi.dll";
    [string] $serviceName = "storeapi01.service";
    [string] $siteUrl = "https://storeapi01.t109.tech";

    DeployAspNetCore60ApiSiteToUbuntuHost -remoteFolder $remoteFolder -projectPath $projectPath -projectBuildPath $projectBuildPath -wwwRootFolder $wwwRootFolder -serviceName $serviceName -executingFileFullPath $executingFileFullPath -siteUrl $siteUrl

}

function LogAndExit ([string] $text)
{
    log $text
    throw $text
    exit
}
function LogAndOutput ([string] $text)
{
    log $text
    $text
}

function DeleteAllFilesFromFolder ([string] $folderName)
{
    Get-ChildItem -Path  $folderName -recurse | Select-Object -ExpandProperty FullName |   Remove-Item -recurse -force 
}


function DeployAspNetCore60ApiSiteToUbuntuHost ([string] $remoteFolder, [string] $projectPath, [string] $projectBuildPath,[string] $wwwRootFolder, [string] $serviceName, [string] $executingFileFullPath, [string] $siteUrl)
{

    LogAndOutput -text  "Deploying site $siteUrl";
    LogAndOutput -text  "Creating session";
    
    # session
    try 
    {
        $deploySession = New-PSSession -HostName $script:deployAddress01 -KeyFilePath "C:\Users\Admin\.ssh\id_rsa";       
    }
    catch 
    {
            log "Unable to crate session: $($_)"
            exit
    }
    
    
    LogAndOutput -text "Session opened successfully";

    # stop service and check if stopped
    Invoke-Command -Session $deploySession -ScriptBlock { Invoke-Expression "sudo systemctl stop  $($args[0])"; } -ArgumentList $serviceName
    PerformSecondsCountDown -seconds 3;
    $isActive = Invoke-Command -Session $deploySession -ScriptBlock    {  Invoke-Expression "sudo systemctl is-active  $($args[0])"; } -ArgumentList $serviceName
    $isActive
    if ($isActive -ne 'inactive') {LogAndExit -text "Unable to stop service $serviceName on remote host, service status=$isActive" }
    
    LogAndOutput -text  "Service $serviceName moved to inactive state";

    # delete folder
    Invoke-Command -Session $deploySession -ScriptBlock    {  Invoke-Expression "sudo rm -r -f  $($args[0])";} -ArgumentList $remoteFolder
    

    # check if folder deleted
    [string] $folderExists = Invoke-Command -Session $deploySession -ScriptBlock    { test-path $args[0]}  -ArgumentList $remoteFolder
    if ($folderExists -ne 'false')   {   LogAndExit -text "Unable to delete folder"  }
    
    LogAndOutput -text  "Remote folder $remoteFolder";

    # --- deploy 

    #  -- build 
    "dotnet build $projectPath --configuration Release" | cmd
    log "Build completed";

    #  -- create dir and copy it all to host
    Invoke-Command -Session $deploySession -ScriptBlock    {  Invoke-Expression "mkdir $($args[0])";} -ArgumentList $remoteFolder
    LogAndOutput -text  "Remote dir $remoteFolder created";

    #  -- copy items to remote
    LogAndOutput -text  "Copying data";
    Copy-Item $projectBuildPath -ToSession $deploySession -Destination $remoteFolder -Recurse -Force ;
    
    if (-not [string]::IsNullOrEmpty($wwwRootFolder))
    {
       Copy-Item $wwwRootFolder -ToSession $deploySession -Destination $remoteFolder -Recurse -Force ;
    }
    LogAndOutput -text  "Finished data copy";

    # give rights to folder
    Invoke-Command -Session $deploySession -ScriptBlock    {  Invoke-Expression "chmod 777 $($args[0])";} -ArgumentList $remoteFolder
    LogAndOutput -text  "Given rights to $remoteFolder on remote host";

    # give execution rights to dll
    Invoke-Command -Session $deploySession -ScriptBlock  {  Invoke-Expression "chmod +X $($args[0])";} -ArgumentList $executingFileFullPath
    LogAndOutput -text  "Given execution rights to dll $executingFileFullPath";

    # start service and check if started
    LogAndOutput -text  "Starting service $serviceName";
    Invoke-Command -Session $deploySession -ScriptBlock  {  Invoke-Expression "sudo systemctl start $($args[0])"; } -ArgumentList $serviceName

    $isActive = Invoke-Command -Session $deploySession -ScriptBlock {  Invoke-Expression "sudo systemctl is-active $($args[0])"; } -ArgumentList $serviceName
    $isActive
    if ($isActive -ne 'active') { LogAndExit -text "Unable to start service $serviceName on remote host" }

    LogAndOutput -text  "Service started";
    LogAndOutput -text  "Deploy completed successfully";

    Start-process -FilePath $operaExeFullPath -ArgumentList $siteUrl;
}


function DeployBalzorWasm60SiteToUbuntuHost ([string] $remoteFolder, [string] $projectPath, [string] $projectBuildPath, [string] $projectBuildZipPath, [string] $siteUrl)
{
    LogAndOutput -text  "Deploying Blazor on Net Core 6.0 site $siteUrl ";
    LogAndOutput -text  "Creating session";
    
    # session
    try {
        $deploySession = New-PSSession -HostName $script:deployAddress01 -KeyFilePath "C:\Users\Admin\.ssh\id_rsa";       
    }
    catch {
            log "Unable to crate session: $($_)"
            exit
    }
    
    LogAndOutput -text "Session opened successfully";

    # delete folder
    Invoke-Command -Session $deploySession -ScriptBlock    {  Invoke-Expression "sudo rm -r -f  $($args[0])";} -ArgumentList $remoteFolder

    # check if folder deleted
    [string] $folderExists = Invoke-Command -Session $deploySession -ScriptBlock    { test-path $args[0]}  -ArgumentList $remoteFolder
    if ($folderExists -ne 'false')   {   LogAndExit -text "Unable to delete folder"  }

    LogAndOutput -text  "Remote folder deleted $remoteFolder";

    # ---- deploy 

    #  -- build 
    DeleteAllFilesFromFolder -folderName $projectBuildPath
    "dotnet publish $projectPath -c Release -o $projectBuildPath --force "  | cmd
    
    log "Publish completed, now gonna copy";

    #  -- create dir and copy it all to host
    Invoke-Command -Session $deploySession -ScriptBlock    {  Invoke-Expression "mkdir $($args[0])";} -ArgumentList $remoteFolder
    LogAndOutput -text  "Remote dir $remoteFolder created";

    #copy files
    Copy-Item "$($projectBuildPath)\*" -ToSession $deploySession -Destination $remoteFolder -Recurse -Force ;

    # give rights to folder
    Invoke-Command -Session $deploySession -ScriptBlock    {  Invoke-Expression "chmod 777 $($args[0])";} -ArgumentList $remoteFolder
    LogAndOutput -text  "Given rights to $remoteFolder on remote host";

    LogAndOutput -text  "Finished data copy";

    LogAndOutput -text  "Deploy completed successfully";
    Start-process -FilePath $operaExeFullPath -ArgumentList $siteUrl;
}


function DeployHtmlAboutmeSite([string] $_transactionId)
{
    if($callType -eq 'plain')
    {
        # this is made to start transaction in a separate window
        [string] $argList = "-file $scriptFileFullPath -transactionId $_transactionId -callType 'external-from-self' ";
        log "starting new process with args: $argList"
        Start-process -FilePath $pwshPath -ArgumentList $argList -PassThru;
        return;
    }

    
    $script:deployAddress01


    # session
    $deploySession = New-PSSession -HostName $script:deployAddress01 -KeyFilePath "C:\Users\Admin\.ssh\id_rsa";   
    

    # delete folder
    Invoke-Command -Session $deploySession -ScriptBlock    {  Invoke-Expression "sudo rm -r -f  /var/www/www-root/data/www/aboutme.t109.tech";}
    

    # check if folder deleted
    [string] $folderExists = Invoke-Command -Session $deploySession -ScriptBlock  { test-path "/var/www/www-root/data/www/aboutme.t109.tech"}
    if ($folderExists -ne 'false')   {   throw;  }
    
    Copy-Item "C:\Develop\SiteData\aboutme.t109.tech" -ToSession $deploySession -Destination "/var/www/www-root/data/www/" -Recurse -Force ;

    Start-process -FilePath $operaExeFullPath -ArgumentList "https://aboutme.t109.tech";

    # copy files
    # robocopy "C:\Develop\SiteData\aboutme.t109.tech" "//$($script:deployHost01)/var/www/www-root/data/www/" /mir /xd;

    # CopyFilesToRemoteHostViaRoboCopy -folderSrc "C:\Develop\SiteData\aboutme.t109.tech" -hostTarget "$($script:deployHost01)" -folderTarget "/var/www/www-root/data/www/";
    # PerformSecondsCountDown -seconds 10
}

function CopyFilesToRemoteHostViaRoboCopy([string] $folderSrc, [string] $hostTarget, [string] $folderTarget )
{
    # this doesnt work
    [string] $srcPath = $folderSrc.Replace(":", "$");
    [string] $targetPath = "\\$($hostTarget)\$($folderTarget)".Replace(":", "$");
    
    $netTarget = new-object -ComObject WScript.Network;
    $netTarget.RemoveNetworkDrive('j:', $true);
    $netTarget.MapNetworkDrive('j:', "$targetPath", $false);

    log "Performing data robocopy from srcPath=$srcPath targetPath=$targetPath"

    # robocopy C:\Develop\SiteData\aboutme.t109.tech //31.31.201.152/var/www/www-root/data/www/ *.* /E
}


#MENU
function ExecMenuItem([string] $menuItem) {

    Log "Executing menu item_$($menuItem)_in operation script"
    
    $ex = $menuItem;

    if ($ex -eq "00")     {    }

    #menubegin
    
    elseif ($ex -eq "100101") { DeployApi01 -_transactionId $ex }
    elseif ($ex -eq "100102") { DeployStore01 -_transactionId $ex }
    elseif ($ex -eq "100110") { DeployHtmlAboutmeSite -_transactionId $ex}

    elseif ($ex -eq "99") { $script:canExit = $true }
    else {
        "Wrong menu number, try again please";
    }
    #menuend
}

CheckLogsDirectory
CLearLogs
SetupCredentials

Log "Script started with params: transactionId=$transactionId, customWokingFolder=$customWokingFolder, callType=$callType"

if ($script:transactionId -ne '') {
    Log "Gonna exec menu item, script:transactionId= $($script:transactionId)";
    ExecMenuItem -menuItem $script:transactionId;
    exit
}

DO {
    PerformCls
    ShowMenu
    $ex = read-host 'Please enter menu point number'
    ExecMenuItem -menuItem $ex
}
WHILE ($script:canExit -eq $false)

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

    $arr=$fileData.Split("`n");

    if($arr.Length -gt 0)
    {
        $deployAddress01 = GetValueFromArray -arr $arr -key 'DeployAddress01' | Select-Object  -Last 1
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
function Test01([string] $_transactionId)
{
    if($callType -eq 'plain')
    {
        [string] $argList = "-file $scriptFileFullPath -transactionId $_transactionId -callType 'external-from-self' ";
        Start-process -FilePath $pwshPath -ArgumentList $argList -PassThru;

        log "performing ps command:"
        log "Start-process -FilePath 'powershell.exe' -ArgumentList $argList -PassThru"

        return;
    }


    # session
    $deploySession = New-PSSession -HostName $deployAddress01 -KeyFilePath "C:\Users\Admin\.ssh\id_rsa";   

    # stop service
    Invoke-Command -Session $deploySession -ScriptBlock    {  Invoke-Expression "sudo systemctl stop api01.service" }

    if ($isActive -eq 'active') { throw; }

    PerformSecondsCountDown -seconds 3;

    $isActive = Invoke-Command -Session $deploySession -ScriptBlock    {  Invoke-Expression "sudo systemctl is-active api01.service"; }
    
    # delete folder
    Invoke-Command -Session $deploySession -ScriptBlock    {  Invoke-Expression "sudo rm -r -f  /var/www/www-root/data/www/storeapi01.t109.tech";}
    
    # check if folder deleted

    [string] $folderExists = Invoke-Command -Session $deploySession -ScriptBlock    { test-path "/var/www/www-root/data/www/storeapi01.t109.tech"}

    "folderExists=$folderExists"

    if ($folderExists -ne 'false')   {   throw;  }

    # --- deploy
    #  -- build 

    [string] $projectPath = "C:\Develop\T109ActivityFrontendFirstSampleVersion\Shop\T109.ActiveDive.EventCatalogue.EventCatalogueApi";

    # Start-process -FilePath 'cmd.exe' -ArgumentList "dotnet build $projectPath"

    "dotnet build $projectPath" | cmd

    [string] $projectPath = "C:\Develop\T109ActivityFrontendFirstSampleVersion\Shop\T109.ActiveDive.EventCatalogue.EventCatalogueApi\bin\Debug\net6.0\";

    # copy it all to host

    # give rights to folder

    # start service
    Invoke-Command -Session $deploySession -ScriptBlock  {  Invoke-Expression "sudo systemctl start api01.service"; }
    PerformSecondsCountDown -seconds 3;
    $isActive = Invoke-Command -Session $deploySession -ScriptBlock    {  Invoke-Expression "sudo systemctl is-active api01.service"; }
    if ($isActive -ne 'active')   {   throw;  }


}

function Test02([string] $_transactionId)
{
    if($callType -eq 'plain')
    {
        [string] $argList = "-file $scriptFileFullPath -transactionId $_transactionId -callType 'external-from-self' ";
        Start-process -FilePath $pwshPath -ArgumentList $argList -PassThru;

        log "performing ps command:"
        log "Start-process -FilePath 'powershell.exe' -ArgumentList $argList -PassThru"

        return;
    }

    write-host "this is 100102";
    
    # PerformSecondsCountDown -seconds 15 -performLog $false;  


}

#MENU
function ExecMenuItem([string] $menuItem) {

    Log "Executing menu item_$($menuItem)_in operation script"
    
    $ex = $menuItem;

    if ($ex -eq "00")     {    }

    #menubegin
    
    elseif ($ex -eq "100101") { Test01 -_transactionId $ex }
    elseif ($ex -eq "100102") { Test02 -_transactionId $ex}

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
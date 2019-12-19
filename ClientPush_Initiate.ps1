# VARIABLES
$sitecodeassign = "FOO" 
$collid = "COLID"
$filelog = 'C:\SCRIPT\ClientPush.log'
$fileloghis = 'C:\SCRIPT\ClientPush.lo_'

###################################################################################################

# Uncomment the line below if running in an environment where script signing is 
# required.
#Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Site configuration
$SiteCode = "FOO" # Site code 
$ProviderMachineName = "SCCM-SERVER" # SMS Provider machine name

# Customizations
$initParams = @{}
#$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
#$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

# Do not change anything below this line

# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}

# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams

###################################################################################################

# MAIN

if (-not (Test-Path $filelog)) {New-Item -Path $filelog -Force | Out-Null } 

$collname = (Get-CMCollection -Id $collid).Name
"*** Start ClientPushInstal collection members '$collname'" | Add-Content $filelog

if ((Get-ChildItem $filelog | Measure-Object -property length -sum).Sum -gt 2621520)
{
    if (Test-Path $fileloghis) { Remove-Item -Path $fileloghis }
    Rename-Item -Path $filelog -NewName $fileloghis
}

$collmembers = Get-CMDevice -CollectionID $collid

foreach ($id in $collmembers) {
    $date = Get-Date -Format u
    $compname = $id.Name

    if (Test-Connection $compname -Quiet -Count 1) {

       "$date $compname available. Starting Client Push Install"  | Add-Content $filelog

       Install-CMClient -DeviceName $id.Name -AlwaysInstallClient $true -ForceReinstall $true -IncludeDomainController $false -SiteCode $sitecodeassign 

    }

    else {

        "$date $compname not available" | Add-Content $filelog

    }
}

"*** End ClientPushInstal collection members '$collname'" | Add-Content $filelog
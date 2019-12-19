# // =================== VARIABLES ================ //

$siteserver = "SCCM-SERVER"
$sitecode = "FOO"
$NameSpace = "root\SMS\Site_$sitecode"

$Location = $PSScriptRoot
$TempLocation = "$Location\Temp"

$filelog = "$Location\AddUpdatesinOfficeDistr.log"
$fileloghis = "$Location\AddUpdatesinOfficeDistr_old.log"

$7Zip = "$Location\7z.exe"

$product2013 = "Office 2013"
$product2016 = "Office 2016"

$2013UpdatesListFile = "$Location\2013updateslist.csv"
$2016UpdatesListFile = "$Location\2016updateslist.csv"

$DestinationFolderUpdates2013 = "C:\Sources\Applications\Microsoft\Office\2013_Pro_x86_Russian\updates"
$DestinationFolderUpdates2016 = "C:\Sources\Applications\Microsoft\Office\2016_Pro_x86_Russian\updates"

$Office2013AppName = 'Microsoft Office 2013 Professional Plus'
$Office2016AppName = 'Microsoft Office 2016 Professional'

# $Product = $product2013
# $DestinationFolderUpdates = $DestinationFolderUpdates2013 
# $UpdatesListFile = $2013UpdatesListFile

# // =================== FUNCTIONS ================ //

function Update-Officeupdates {
    param (
        [PARAMETER(Mandatory=$True)]$Product,
        [PARAMETER(Mandatory=$True)]$DestinationFolderUpdates,
        [PARAMETER(Mandatory=$True)]$UpdatesListFile,
        $AppName
    )
    
    Add-Content -Path $filelog -Value "Start check for $Product"
    # Get product CategoryInstance_UniqueID
    $ProductID = (Get-WmiObject -ComputerName $siteserver -Namespace $NameSpace -Query "SELECT CategoryInstance_UniqueID FROM SMS_UpdateCategoryInstance WHERE LocalizedCategoryInstanceName = '$Product'").CategoryInstance_UniqueID

    # Get UpdateIDs
    $UpdateIDs = Get-WmiObject -ComputerName $siteserver -Namespace $NameSpace -Query "SELECT ci.* FROM SMS_SoftwareUpdate ci  WHERE ( CI_ID in (select CI_ID from SMS_CIAllCategories where CategoryInstance_UniqueID='$ProductID') )" | Select-Object -Property CI_ID, DatePosted, LocalizedDisplayName | Sort-Object -Property DatePosted

    # Filter 64-bit, Access, InfoPath, Project, SharePoint, SkyDrive, Visio, Audit and Control Management Server, Office Web Apps
    $UpdateIDs = $UpdateIDs | Where-Object { $PSItem.LocalizedDisplayName -notlike "*64-*" -and $PSItem.LocalizedDisplayName -notlike "*Access*" -and $PSItem.LocalizedDisplayName -notlike "*InfoPath*" -and $PSItem.LocalizedDisplayName -notlike "*Project*" -and $PSItem.LocalizedDisplayName -notlike "*SharePoint*" -and $PSItem.LocalizedDisplayName -notlike "*SkyDrive*" -and $PSItem.LocalizedDisplayName -notlike "*Visio*" -and $PSItem.LocalizedDisplayName -notlike "*Audit and Control Management Server*" -and $PSItem.LocalizedDisplayName -notlike "*Office Web Apps*" }

    # Get ContentIDs
    $ContentIDs = $UpdateIDs | ForEach-Object {(Get-WmiObject -ComputerName $siteserver -Namespace $NameSpace -Query "select * from SMS_CItoContent where ci_id='$($PSItem.CI_ID)'").ContentID}

    # Get SourceURL and FileName
    $Contents = $ContentIDs | ForEach-Object { Get-WmiObject -ComputerName $siteserver -Namespace $NameSpace -Class SMS_CIContentFiles -Filter "ContentID = '$PSItem'" } | Select-Object FileName, SourceURL
    
    # Filter other language updates
    $Contents = $Contents | Where-Object { $PSItem.FileName -like "*-en-us.cab" -or $PSItem.FileName -like "*-ru-ru.cab" -or $PSItem.FileName -notlike "*-??.cab" }

    # Filter files infopath, project, sharepoint, visio
    $Contents = $Contents | Where-Object { $PSItem.FileName -notlike "*infopath*" -and $PSItem.FileName -notlike "*project*" -and $PSItem.FileName -notlike "*sharepoint*" -and $PSItem.FileName -notlike "*visio*" }

    # Get updates list that were added earler
    $UpdatesList = Import-Csv $UpdatesListFile

    $Contents | ForEach-Object {

        $URL = $PSItem.SourceURL
        $Cabfilename = $URL | Split-Path -Leaf

        #Compare
        if ($null -eq $($UpdatesList | Where-Object {$PSItem.SourceURL -EQ $URL})) {
                try 
                {
                    Add-Content -Path $filelog -Value "Adding update $($PSItem.SourceURL)"
                    Start-BitsTransfer -Source $PSItem.SourceURL -Destination "$TempLocation"
                    & $7Zip "x" "$TempLocation\$Cabfilename" "-o$DestinationFolderUpdates" *.msp -aoa
                }
                catch
                {
                    Add-Content -Path $filelog -Value "Error downloading update $($PSItem.SourceURL)"
                }
            }

    }

    # Re-create Updateslist
    if (Test-Path $UpdatesListFile) { Remove-Item $UpdatesListFile -Force }
    $Contents | Export-Csv $UpdatesListFile

    # Clean temp location
    if (Test-Path $TempLocation) { Get-ChildItem $TempLocation | Remove-Item -Recurse -Force }

}

# // =================== MAIN ================ //

# Create temp location
if ((Test-Path $TempLocation) -eq $false) { New-Item -ItemType Directory -Force -Path $TempLocation }

# Create log file if not exist.
if (-not (Test-Path $filelog)) {New-Item -Path $filelog -Force | Out-Null}

# Rename file if greater than 2Mb
if ((Get-ChildItem $filelog | Measure-Object -property length -sum).Sum -gt 2621520)
{
    if (Test-Path $fileloghis) { Remove-Item -Path $fileloghis }
    Rename-Item -Path $filelog -NewName $fileloghis
}

Add-Content -Path $filelog -Value "--- Start --- $(Get-Date -Format u) -----------------------------------------------"

Update-Officeupdates -Product $product2013 -DestinationFolderUpdates $DestinationFolderUpdates2013 -UpdatesListFile $2013UpdatesListFile

Add-Content -Path $filelog -Value "-----------------------------------------------------------------------------------"

Update-Officeupdates -Product $product2016 -DestinationFolderUpdates $DestinationFolderUpdates2016 -UpdatesListFile $2016UpdatesListFile

Add-Content -Path $filelog -Value "-----------------------------------------------------------------------------------"

Add-Content -Path $filelog -Value "Update content on DP's"

# Import the ConfigurationManager module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
}

# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $siteserver
}

# Save current location
$SaveLocation = Get-Location

# Set the current location to be the site code.
Set-Location "$($SiteCode):\"

# Update Offcie 2013 content on DP's
$Office2013DT = Get-CMDeploymentType -ApplicationName $Office2013AppName
Update-CMDistributionPoint -ApplicationName $Office2013AppName -DeploymentTypeName $Office2013DT.LocalizedDisplayName

# Update Offcie 2016 content on DP's
$Office2016DT = Get-CMDeploymentType -ApplicationName $Office2016AppName
Update-CMDistributionPoint -ApplicationName $Office2016AppName -DeploymentTypeName $Office2016DT.LocalizedDisplayName

# Return location
Set-Location $SaveLocation

Add-Content -Path $filelog -Value "--- End --- $(Get-Date -Format u) -----------------------------------------------"

# End
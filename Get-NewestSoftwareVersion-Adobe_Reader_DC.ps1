#region VARIABLES
$Application = 'Adobe Acrobat Reader DC - Russian'
$downloadFolder = "\\SCCM-SERVER\Sources\Adobe\Acrobat Reader DC - Russian"

$AvailableApplicationName = 'Adobe Acrobat Reader DC - Russian | Available'
$AvailableApplicationSources = "$downloadFolder\Current Version"

$releases = 'https://supportdownloads.adobe.com/product.jsp?product=1&platform=Windows'

#$filelog = "C:\SCRIPT\Software Check\SoftwareCheck.log"
$filelog = "$PSScriptRoot\SoftwareCheck.log"

$SiteCode = "FOO"
$ProviderMachineName = "SCCM-SERVER"
#endregion VARIABLES

#region FUNCTIONS
function New-Application {
    param (
        [PARAMETER(Mandatory=$True)]$ApplicationName,
        [PARAMETER(Mandatory=$True)]$SourcesPath,
        $ProviderMachineName = "SCCM-SERVER",
        $SiteCode = "FOO",
        $Application = 'Adobe Acrobat Reader DC - Russian',
        $DirAppinConsole = 'Adobe',
        $Description = 'Created by Script',
        [PARAMETER(Mandatory=$True)]$Version,
        $Publisher = 'Adobe',
        $InstallationProgram = '"install.cmd"',
        $DPGroup = 'Distribution Point Group',
        $TestCollection = 'DA | Adobe Acrobat Reader DC - Russian | Update Only | Pilot | Required',
        $ProdCollection = 'DA | Adobe Acrobat Reader DC - Russian | Update Only | Prod | Required',
        $DetectScript
    )
    
    # $Version = $newversion
    # $SourcesPath = $targetDirectory
    $DetectScript = "Get-ItemProperty 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object {`$_.DisplayName -like `"Adobe Acrobat Reader DC*`" -and `$_.Displayversion -like `"${Version}`"}"

    #region Import the ConfigurationManager module
        if((Get-Module ConfigurationManager) -eq $null) {
            Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
        }
        # Connect to the site's drive if it is not already present
        if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
            New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName 
        }
        $SaveLocation = Get-Location
        Set-Location "$($SiteCode):\"
    #endregion

    # Create Application
    New-CMApplication -Name $ApplicationName -LocalizedApplicationName $ApplicationName -Description $Description -SoftwareVersion $Version

    # Create Deployment Type
    Add-CMScriptDeploymentType -ApplicationName $ApplicationName -DeploymentTypeName $ApplicationName `
        -InstallationFileLocation "$SourcesPath" -InstallationProgram $InstallationProgram `
        -InstallationBehaviorType InstallForSystem -LogonRequirementType WhetherOrNotUserLoggedOn -UserInteractionMode Hidden `
        -ScriptLanguage PowerShell -ScriptText $DetectScript -RebootBehavior NoAction

    # Move Application in Folder
    if ($DirAppinConsole -ne $null) {
        $Apps = Get-WmiObject -Namespace Root\SMS\Site_$SiteCode -Class SMS_ApplicationLatest -Filter "LocalizedDisplayName='$ApplicationName'"
        $TargetFolderID = Get-WmiObject -Namespace Root\SMS\Site_$SiteCode -Class SMS_ObjectContainerNode -Filter "ObjectType='6000' and Name='$DirAppinConsole'"
        $CurrentFolderID = 0
        $ObjectTypeID = 6000
        $WMIConnectionString = "\\$ProviderMachineName\root\SMS\Site_$SiteCode" + ":SMS_objectContainerItem"
        $WMIConnection = [WMIClass]$WMIConnectionString
        $MoveItem = $WMIConnection.psbase.GetMethodParameters("MoveMembers")
        $MoveItem.ContainerNodeID = $CurrentFolderID
        $MoveItem.InstanceKeys = $Apps.ModelName
        $MoveItem.ObjectType = $ObjectTypeID
        $MoveItem.TargetContainerNodeID = $TargetFolderID.ContainerNodeID
        $WMIConnection.psbase.InvokeMethod("MoveMembers", $MoveItem, $null)
    }

    # Distribute content on DP
    Start-CMContentDistribution -ApplicationName $ApplicationName -DistributionPointGroupName $DPGroup

    #Remove previous deployments
    Get-CMDeployment -CollectionName $TestCollection | Where-Object { $PSItem.ApplicationName -like "${Application}*" } | Remove-CMDeployment -Force
    Get-CMDeployment -CollectionName $ProdCollection | Where-Object { $PSItem.ApplicationName -like "${Application}*" } | Remove-CMDeployment -Force
    
    # Create deployments
    $DateTest = (Get-Date).AddHours(3)
    $DateProd = (Get-Date).AddDays(14)
    New-CMApplicationDeployment -Name $ApplicationName -CollectionName $TestCollection -DeployPurpose Required -UserNotification HideAll -AvailableDateTime $DateTest
    New-CMApplicationDeployment -Name $ApplicationName -CollectionName $ProdCollection -DeployPurpose Required -UserNotification HideAll -AvailableDateTime $DateProd

    # Return Location
    Set-Location $SaveLocation

    # Generate Mail Body
    $global:Body = @"
Available new version.
Created application '$ApplicationName'.
Deployment assigned to '$TestCollection' starts on $DateTest.
Deployment assigned to '$ProdCollection' starts on $DateProd.
and updated application $AvailableApplicationName.
"@

    # Return Location
    Set-Location $SaveLocation

}

function Update-VersionCompliance {
    param (
        $SiteCode = "FOO",
        $ProviderMachineName = "SCCM-SERVER",
        $RuleName = "GreaterEquals",
        [PARAMETER(Mandatory=$True)][String]$SoftwareName,
        [PARAMETER(Mandatory=$True)]$NewVersion
    )

    #region Import the ConfigurationManager module
    if((Get-Module ConfigurationManager) -eq $null) {
        Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
    }
    # Connect to the site's drive if it is not already present
    if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
        New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName 
    }
    $SaveLocation = Get-Location
    Set-Location "$($SiteCode):\"
    #endregion

    # Find Configuration Item
    $CIName = (Get-CMConfigurationItem -Fast | Where-Object {$_.LocalizedDisplayName -Like "$SoftwareName*"}).LocalizedDisplayName

    # Check Found Single Item
    $CountCI = ($CIName).Count
    If ($CountCI -ne "1") {
        return
    }

    # Set ExpectedValue in Compliance Rule
    Get-CMConfigurationItem -Name $CIName -Fast | Set-CMComplianceRuleValue -RuleName $RuleName -ExpectedValue $NewVersion

    # Rename Configuration Item
    $NewCIName = $SoftwareName + " " + $NewVersion
    Set-CMConfigurationItem -Name $CIName -NewName $NewCIName

    # Return Location
    Set-Location $SaveLocation
    
}
function Send-EmailAnonymously {
        param (
                $User = "anonymous",
                $SMTPServer = "SMTP-SERVER",
                $From = "sccm@domain",
                [PARAMETER(Mandatory=$True)]$To,
                $Subject = "Available new version Adobe Acrobat Reader DC - Russian",
                $Body
        )

        $PWord = ConvertTo-SecureString -String "anonymous" -AsPlainText -Force

        $Creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord

        Send-MailMessage -From $From -To $To -Subject $Subject -Body $Body -SmtpServer $SMTPServer -Credential $Creds -Encoding Default -Priority High

}
#endregion FUNCTIONS

#region MAIN

# Create HTML file Object
$HTMLObject = New-Object -Com "HTMLFile"
$html = Invoke-WebRequest -Uri $releases -UseBasicParsing
$Content = $html.Content
# Write HTML content according to DOM Level2 
$HTMLObject.IHTMLDocument2_write($Content)

#$newversion = $HTMLObject.all.tags("th") | ForEach-Object InnerText | Where-Object { $PSItem -like 'Version *' } | Select-Object -First 1
#$newversion = $newversion -replace "Version"
#$newversion = $newversion -replace " "

$LinktoProduct = $HTMLObject.links | Where-Object { $PSItem.textContent -eq 'Adobe Acrobat DC Pro and Standard (Continuous Track) update - All languages' } | Select-Object -Property href -First 1
$LinktoProduct = ($LinktoProduct).href -replace "about:"
$LinktoProduct = "https://supportdownloads.adobe.com/$LinktoProduct"

#Proceed to Download
$HTMLObject = New-Object -Com "HTMLFile"
$html = Invoke-WebRequest -Uri $LinktoProduct -UseBasicParsing
$Content = $html.Content
$HTMLObject.IHTMLDocument2_write($Content)

$LinkProceedtoDownload = $HTMLObject.links | Where-Object { $PSItem.textContent -eq 'Proceed to Download' } | Select-Object -Property href -First 1
$HTMLObject.links | Where-Object { $PSItem.href -like '*detail.jsp?ftpID=6561*' }
$LinkProceedtoDownload = ($LinkProceedtoDownload).href -replace "about:"
$LinkProceedtoDownload = "https://supportdownloads.adobe.com/$LinkProceedtoDownload"

#DownloadNow
$HTMLObject = New-Object -Com "HTMLFile"
$html = Invoke-WebRequest -Uri $LinkProceedtoDownload -UseBasicParsing
$Content = $html.Content
$HTMLObject.IHTMLDocument2_write($Content)


$LinkDownloadNow = $HTMLObject.links | Where-Object { $PSItem.textContent -eq 'Download Now' } | Select-Object -Property href -First 1
$LinkDownloadNow = ($LinkDownloadNow).href


# Get version
$fileversion = $LinkDownloadNow |Split-Path -Leaf
$newversion = [System.IO.Path]::GetFileNameWithoutExtension("$fileversion")
$newversion = $newversion.split('_')[0]
$newversion -match '\d+'
$newversion = $Matches[0]
$newversion = $newversion.Insert(2,".")
$newversion = $newversion.Insert(6,".")

if ($newversion -eq $null -or $newversion -eq "") {
        Add-Content -Path $filelog -Value "$Application. Failed to parse version on webpage. Exit --- $(Get-Date -Format u)"
        exit
}

$SourcesPath = "$downloadFolder\$newversion Update Only"

if (Test-Path "$SourcesPath") {
        Add-Content -Path $filelog -Value "$Application version $newversion has already been downloaded. Exit --- $(Get-Date -Format u)"
        exit 
}

Add-Content -Path $filelog -Value "$Application - found new version $newversion. Download and create application with deployments. --- $(Get-Date -Format u)"

New-Item -ItemType Directory -Path "$SourcesPath" -Force

# Download file
$webclient = New-Object System.Net.WebClient
$webclient.DownloadFile($LinkDownloadNow, "$SourcesPath\$fileversion")

# Create install.cmd
Add-Content -Path "$SourcesPath\install.cmd" -Value '@ECHO OFF'
Add-Content -Path "$SourcesPath\install.cmd" -Value "$fileversion /qn /norestart"

$ApplicationName = $Application + ' ' + $newversion + ' | Update Only'

# Create application
New-Application -ApplicationName $ApplicationName -SourcesPath $SourcesPath -Version $newversion

# Update CI
Update-VersionCompliance -SoftwareName $Application -NewVersion $newversion

#region Update Available Application

    Copy-Item -Path "$SourcesPath\$fileversion" -Destination "$AvailableApplicationSources\AcroRdrDCUpd.msp" -Force

        #region Import the ConfigurationManager module
        if((Get-Module ConfigurationManager) -eq $null) {
            Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
        }
        # Connect to the site's drive if it is not already present
        if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
            New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName 
        }
        $SaveLocation = Get-Location
        Set-Location "$($SiteCode):\"
        #endregion

    # Update content on DP's
    $AvailableApplicationNameDT = Get-CMDeploymentType -ApplicationName AvailableApplicationName
    Update-CMDistributionPoint -ApplicationName AvailableApplicationName -DeploymentTypeName $AvailableApplicationNameDT.LocalizedDisplayName

    # Update version of the Application
    Set-CMApplication -ApplicationName $AvailableApplicationName -SoftwareVersion $newversion

    # Update detection script
    Get-CMDeploymentType -ApplicationName $AvailableApplicationName |
    Set-CMScriptDeploymentType -ScriptLanguage Powershell -ScriptText "Get-ItemProperty 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object {`$_.DisplayName -like `"Adobe Acrobat Reader DC*`" -and `$_.Displayversion -like `"${newversion}`"}"

    # Return Location
    Set-Location $SaveLocation

#endregion Update Available Application

# Send Mail
Send-EmailAnonymously -Body $global:Body -To "to.mail@domain"

#endregion MAIN
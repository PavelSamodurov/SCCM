#region Variables
$LogFile = "C:\Temp\CleanUpSystemDisk.log"
$DiskSpaceResult = @()
$Global:Result = @()

$Global:ExclusionList = @()
$Global:TotalSccmClearCacheDeletedSize = 0
#endregion Variables

#region Finctions

function Get-DiskSpace ($Comment) {
    Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq "3" -and $_.DeviceID -eq "C:"} | Select-Object SystemName,
    @{ Name = "Comment" ; Expression = { ( $Comment ) } },
    @{ Name = "Drive" ; Expression = { ( $_.DeviceID ) } },
    @{ Name = "Size (GB)" ; Expression = {"{0:N1}" -f ( $_.Size / 1gb)}},
    @{ Name = "FreeSpace (GB)" ; Expression = {"{0:N1}" -f ( $_.Freespace / 1gb ) } },
    @{ Name = "FreeSpace" ; Expression = {"{0:N1}" -f ( $_.Freespace ) } },
    @{ Name = "PercentFree" ; Expression = {"{0:P1}" -f ( $_.FreeSpace / $_.Size ) } }
}

function Remove-Files {
    param (
        [PARAMETER(Mandatory=$True)]$Path,
        $FileMask = '*.*',
        $Exclude = 'EXCLUDE_UNDIFINED',
        $DaysToDelete = 0
    )

    Write-Host '***********************'
    Write-Host "Deleting $FileMask files in `"$Path`" older than $DaysToDelete days:"
    
    $FilesToDelete = Get-ChildItem $Path -Filter $FileMask -Exclude $Exclude -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object {($_.Directory -ne $null) -and ($_.LastWriteTime -lt $(Get-Date).AddDays( - $DaysToDelete)) -and ($_.FullName -notlike "*$Exclude*")}

    $FilesSize = 0
    $FilesCount = 0
    foreach ($File in $FilesToDelete) {
        try {
            Remove-Item -Path $File.FullName -Force -ErrorAction Stop -Verbose
            $FilesSize += $File.Length
            $FilesCount++
        } catch {
            Write-Host "Cannot delete $($File.FullName)"
        }
    }
    # Delete Folders
    if ($FileMask -eq '*.*' -and $DaysToDelete -eq '0') {        
        try {
            Get-ChildItem $Path -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object {($_.FullName -notlike "*$Exclude*")} |
            Remove-Item  -Recurse -Force -ErrorAction Stop -Verbose
        } catch {
            Write-Host "Cannot delete Folder in $Path"
        }
    }
    

    Write-Host "Deleted $FilesCount files with a total size of $([math]::Round($FilesSize/(1024*1024), 2)) MB in $Path"
    $Global:Result += "Deleted $FilesCount files with a total size of $([math]::Round($FilesSize/(1024*1024), 2)) MB in $Path"
    Write-Host '***********************'
}

function Start-DISM {
    
    $ErrorActionPreference = 'Stop'
    
    Write-Host 'Start "Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase"'
    try {
        Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase
        $ErrorActionPreference = 'SilentlyContinue'
    }
    catch {
        $ErrorActionPreference = 'SilentlyContinue'
        Write-Host 'Failed ComponentCleanup.'
    }
    
    Write-Host '***********************'
    Write-Host 'Start "Dism.exe /Online /Cleanup-Image /SPSuperseded"'
    try {
        Dism.exe /Online /Cleanup-Image /SPSuperseded
        $ErrorActionPreference = 'SilentlyContinue'
    } catch [System.Exception]{
        $ErrorActionPreference = 'SilentlyContinue'
        Write-Host 'Unable to clean old ServicePack Files.'
    }

    $ErrorActionPreference = 'SilentlyContinue'
    # if ($DISMResultSpsuperseded -match 'The operation completed successfully'){
    #     Write-Host "DISM Completed Successfully." -ForegroundColor Green
    # } else {
    #     Write-Host "Unable to clean old ServicePack Files." -ForegroundColor Red
    # }
}

function Remove-CacheItem { 
    <# 
    .SYNOPSIS 
        Removes SCCM cache item if it's not persisted. 
    .DESCRIPTION 
        Removes specified SCCM cache item if it's not found in the persisted cache list. 
    .PARAMETER CacheItemToDelete 
        The cache item ID that needs to be deleted. 
    .PARAMETER CacheItemName 
        The cache item name that needs to be deleted. 
    .EXAMPLE 
        Remove-CacheItem -CacheItemToDelete '{234234234}' -CacheItemName 'Office2003' 
    .NOTES 
        This is an internal script function and should typically not be called directly. 
    .LINK 
        http://sccm-zone.com 
    #> 
        [CmdletBinding()] 
        Param ( 
            [Parameter(Mandatory=$true,Position=0)] 
            [Alias('CacheTD')] 
            [string]$CacheItemToDelete, 
            [Parameter(Mandatory=$true,Position=1)] 
            [Alias('CacheN')] 
            [string]$CacheItemName 
        ) 
     
        ## Delete cache item if it's non persisted 
        If ($CacheItems.ContentID -contains $CacheItemToDelete) { 
     
            #  Get Cache item location and size 
            $CacheItemLocation = $CacheItems | Where-Object {$_.ContentID -Contains $CacheItemToDelete} | Select-Object -ExpandProperty Location 
            $CacheItemSize =  Get-ChildItem $CacheItemLocation -Recurse -Force | Measure-Object -Property Length -Sum | Select-Object -ExpandProperty Sum 
     
            #  Check if cache item is downloaded by looking at the size 
            If ($CacheItemSize -gt '0.00') { 
     
                #  Connect to resource manager COM object 
                $CMObject = New-Object -ComObject 'UIResource.UIResourceMgr' 
     
                #  Using GetCacheInfo method to return cache properties
                $CMCacheObjects = $CMObject.GetCacheInfo() 
                
                #  Delete Cache item 
                $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentID -eq $CacheItemToDelete} | 
                    ForEach-Object { 
                        try {
                            $CMCacheObjects.DeleteCacheElement($_.CacheElementID)
                            Write-Host "Deleted $CacheItemName (ID:$CacheItemToDelete) in $CacheItemLocation. Size: $('{0:N2}' -f ($CacheItemSize / 1MB)) MB"
                            $Global:TotalSccmClearCacheDeletedSize += '{0:N2}' -f ($CacheItemSize / 1MB) 
                        } catch {
                            Write-Host "$CacheItemName (ID:$CacheItemToDelete) in use by a running program or by a download in progress."
                        }
                    }
            }
        } else {
            # Write-Host 'Already Deleted:'$CacheItemName '|| ID:'$CacheItemToDelete -BackgroundColor Green 
        }
}

function Remove-CachedApplications { 
    <# 
    .SYNOPSIS 
        Removes cached application. 
    .DESCRIPTION 
        Removes specified SCCM cache application if it's already installed. 
    .EXAMPLE 
        Remove-CachedApplications 
    .NOTES 
        This is an internal script function and should typically not be called directly. 
    .LINK 
        http://sccm-zone.com 
    #> 
        
        ## Get list of applications 
        Try { 
            $CM_Applications = Get-WmiObject -Namespace root\ccm\ClientSDK -Query 'SELECT * FROM CCM_Application' -ErrorAction Stop 
        } 
        #  Write to log in case of failure 
        Catch { 
            Write-Host 'Get SCCM Application List from WMI - Failed!' 
        } 
        
        ## Check for installed applications 
        Foreach ($Application in $CM_Applications) { 
        
            ## Get Application Properties 
            $Application.Get()
        
            ## Enumerate all deployment types for an application 
            Foreach ($DeploymentType in $Application.AppDTs) { 
        
                ## Get content ID for specific application deployment type 
                $AppType = 'Install',$DeploymentType.Id,$DeploymentType.Revision 
                $AppContent = Invoke-WmiMethod -Namespace root\ccm\cimodels -Class CCM_AppDeliveryType -Name GetContentInfo -ArgumentList $AppType 
        
                If ($Application.InstallState -eq 'Installed' -and $Application.IsMachineTarget -and $AppContent.ContentID) { 
        
                    ## Call Remove-CacheItem function 
                    Remove-CacheItem -CacheTD $AppContent.ContentID -CacheN $Application.FullName 
                } 
                Else { 
                    ## Add to exclusion list 
                    $Global:ExclusionList += $AppContent.ContentID 
                } 
            } 
        } 
}

function Remove-CachedPackages { 
    <# 
    .SYNOPSIS 
        Removes SCCM cached package. 
    .DESCRIPTION 
        Removes specified SCCM cached package if it's not needed anymore. 
    .EXAMPLE 
        Remove-CachedPackages 
    .NOTES 
        This is an internal script function and should typically not be called directly. 
    .LINK 
        http://sccm-zone.com 
    #> 
        
        ## Get list of packages 
        Try { 
            $CM_Packages = Get-WmiObject -Namespace root\ccm\ClientSDK -Query 'SELECT PackageID,PackageName,LastRunStatus,RepeatRunBehavior FROM CCM_Program' -ErrorAction Stop 
        } 
        #  Write to log in case of failure 
        Catch { 
            Write-Host 'Get SCCM Package List from WMI - Failed!' 
        } 
        
        ## Check if any deployed programs in the package need the cached package and add deletion or exemption list for comparison 
        ForEach ($Program in $CM_Packages) { 
        
            #  Check if program in the package needs the cached package 
            If ($Program.LastRunStatus -eq 'Succeeded' -and $Program.RepeatRunBehavior -ne 'RerunAlways' -and $Program.RepeatRunBehavior -ne 'RerunIfSuccess') { 
        
                #  Add PackageID to Deletion List if not already added 
                If ($Program.PackageID -NotIn $PackageIDDeleteTrue) { 
                    [Array]$PackageIDDeleteTrue += $Program.PackageID 
                } 
        
            } 
            Else { 
        
                #  Add PackageID to Exemption List if not already added 
                If ($Program.PackageID -NotIn $PackageIDDeleteFalse) { 
                    [Array]$PackageIDDeleteFalse += $Program.PackageID 
                } 
            }
        }
        
        ## Parse Deletion List and Remove Package if not in Exemption List 
        ForEach ($Package in $PackageIDDeleteTrue) { 
    
            #  Call Remove Function if Package is not in $PackageIDDeleteFalse 
            If ($Package -NotIn $PackageIDDeleteFalse) { 
                Remove-CacheItem -CacheTD $Package.PackageID -CacheN $Package.PackageName 
            } 
            Else { 
                ## Add to exclusion list 
                $Global:ExclusionList += $Package.PackageID 
            } 
        }
}

function Remove-CachedUpdates { 
    <# 
    .SYNOPSIS 
        Removes SCCM cached updates. 
    .DESCRIPTION 
        Removes specified SCCM cached update if it's not needed anymore. 
    .EXAMPLE 
        Remove-CachedUpdates 
    .NOTES 
        This is an internal script function and should typically not be called directly. 
    .LINK 
        http://sccm-zone.com 
    #> 
     
        ## Get list of updates 
        Try { 
            $CM_Updates = Get-WmiObject -Namespace root\ccm\SoftwareUpdates\UpdatesStore -Query 'SELECT UniqueID,Title,Status FROM CCM_UpdateStatus' -ErrorAction Stop 
        } 
        #  Write to log in case of failure 
        Catch { 
            Write-Host 'Get SCCM Software Update List from WMI - Failed!' 
        } 
     
        ## Check if cached updates are not needed and delete them 
        ForEach ($Update in $CM_Updates) { 
     
            #  Check if update is already installed 
            If ($Update.Status -eq 'Installed') { 
     
                #  Call Remove-CacheItem function 
                Remove-CacheItem -CacheTD $Update.UniqueID -CacheN $Update.Title 
            } 
            Else { 
                ## Add to exclusion list 
                $Global:ExclusionList += $Update.UniqueID 
            } 
        } 
}

function Remove-OrphanedCacheItems { 
    <# 
    .SYNOPSIS 
        Removes SCCM orphaned cached items. 
    .DESCRIPTION 
        Removes SCCM orphaned cache items not found in Applications, Packages or Update WMI Tables. 
    .EXAMPLE 
        Remove-OrphanedCacheItems 
    .NOTES 
        This is an internal script function and should typically not be called directly. 
    .LINK 
        http://sccm-zone.com 
    #> 
     
        ## Check if cached updates are not needed and delete them 
        ForEach ($CacheItem in $CacheItems) { 
     
            #  Check if update is already installed 
            If ($Global:ExclusionList -notcontains $CacheItem.ContentID) { 
     
                #  Call Remove-CacheItem function 
                Remove-CacheItem -CacheTD $CacheItem.ContentID -CacheN 'Orphaned Cache Item' 
            }
        }
}
#endregion Functions

#region Main

#  Rename log it it's more than 2 MB 
if (Test-Path $LogFile) { 
    if ((Get-Item $LogFile).Length -gt 2MB) { 
        Move-Item -Path $LogFile -Destination $($LogFile.Insert(($LogFile.Length - 4),'_old')) -Force
    }
}

Start-Transcript -Path $LogFile -Append -Force
Write-Host '***********************'
Write-Host '******* Start *********'
Write-Host $(Get-Date)
Write-Host '***********************'

$DiskSpaceBefore = Get-DiskSpace -comment 'Before'
$DiskSpaceResult += $DiskSpaceBefore

Write-Host '***********************'
Write-Host 'Start deleting files'
Write-Host '***********************'

#Remove-Files -Path 'C:\Temp\'
Remove-Files -Path 'C:\Temp\Logs\'-daysToDelete '21'
Remove-Files -Path 'C:\Windows\Temp\' -Exclude 'BootImages'
Remove-Files -Path 'C:\Windows\logs\CBS\' -fileMask '*.log'
Remove-Files -Path 'C:\inetpub\logs\LogFiles\' -daysToDelete '2'
Remove-Files -Path 'C:\PerfLogs\'
#Remove-Files -Path 'C:\Windows\memory.dmp' -fileMask 'memory.dmp' -daysToDelete '7'
Remove-Files -Path 'C:\Windows\minidump\' -daysToDelete '92'
Remove-Files -Path 'C:\ProgramData\Microsoft\Windows\WER\'
Remove-Files -Path 'C:\Config.Msi\'
#Remove-Files -Path 'C:\Windows\Prefetch\'
Remove-Files -Path 'C:\Users\*\AppData\Local\Temp\'
#Remove-Files -Path 'C:\Users\*\Appdata\Local\Google\Chrome\User Data\Default\Cache\*'
#Remove-Files -Path 'C:\Users\*\AppData\Local\Google\Chrome\User Data\Default\Local Storage\*'
#Remove-Files -Path 'C:\Users\*\Appdata\Local\Google\Chrome\User Data\Default\Media Cache\*'
#Remove-Files -Path 'C:\Users\*\Appdata\Local\Google\Chrome\User Data\Default\Pepper Data\*'
Remove-Files -Path 'C:\Users\*\Appdata\Local\Microsoft\OneNote\14.0\OneNoteOfflineCache_Files\'
Remove-Files -Path 'C:\Users\*\Appdata\Local\Microsoft\Terminal Server Client\Cache\'
#Remove-Files -Path 'C:\Users\*\AppData\Local\Microsoft\Windows\IECompatCache\*'
#Remove-Files -Path 'C:\Users\*\AppData\Local\Microsoft\Windows\IECompatUaCache\*'
#Remove-Files -Path 'C:\Users\*\AppData\Local\Microsoft\Windows\IEDownloadHistory\*'
#Remove-Files -Path 'C:\Users\*\AppData\Local\Microsoft\Windows\INetCache\*'
#Remove-Files -Path 'C:\Users\*\AppData\Local\Microsoft\Windows\INetCookies\*'
#Remove-Files -Path 'C:\Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\*'
Remove-Files -Path 'C:\Users\*\AppData\Local\Microsoft\Windows\WER\'
Remove-Files -Path 'C:\Users\*\Appdata\Local\Mozilla\Firefox\cache\'
Remove-Files -Path 'C:\Users\*\Appdata\Local\Mozilla\Firefox\Profiles\*\cache\'
Remove-Files -Path 'C:\Users\*\Appdata\Local\Mozilla\Firefox\Profiles\*\cache2\'
Remove-Files -Path 'C:\Users\*\Appdata\Local\Opera\Opera\cache\'
Remove-Files -Path 'C:\Users\*\Appdata\LocalLow\Sun\Java\Deployment\cache\'
#Remove-Files -Path 'C:\Users\*\Appdata\Microsoft\Feeds?Cache\*'
Remove-Files -Path 'C:\Users\*\Appdata\Roaming\Adobe\Flash Player\AssetCache\'
Remove-Files -Path 'C:\Users\*\Appdata\Roaming\Macromedia\Flash Player\#SharedObjects\'
Remove-Files -Path 'C:\Users\*\Appdata\Roaming\Macromedia\Flash Player\macromedia.com\support\flashplayer\sys\'
Remove-Files -Path 'C:\Users\*\Appdata\Roaming\Macromedia\Flashp~1\'
#Remove-Files -Path 'C:\Users\*\Appdata\Roaming\Microsoft\Internet Explorer\UserData\Low\*'
Remove-Files -Path 'C:\Users\*\Appdata\Roaming\Microsoft\Windows\Cookies\'
Remove-Files -Path 'C:\Users\*\Appdata\Roaming\Mozilla\Firefox\Crash Reports\'
#Remove-Files -Path 'C:\Windows\System32\config\systemprofile\AppData\Local\Google\Chrome\User Data\Default\Cache\*'
#Remove-Files -Path 'C:\Windows\System32\config\systemprofile\AppData\Local\Microsoft\Windows\Temporary Internet Files\Content.IE5\*'
#Remove-Files -Path 'C:\$Recycle.Bin\' -DaysToDelete '30'

Get-Service -Name wuauserv | Stop-Service -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
Remove-Files -Path 'C:\Windows\SoftwareDistribution\'
Get-Service -Name wuauserv | Start-Service -ErrorAction SilentlyContinue

Write-Host '***********************'
Write-Host 'Call Start-DISM function'

# Call Start-DISM function
$WinsxsSizeBefore = (Get-ChildItem C:\Windows\WinSxS\ -Recurse | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum / 1MB
Start-DISM
$WinsxsSizeAfter = (Get-ChildItem C:\Windows\WinSxS\ -Recurse | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum / 1MB

Write-Host "Total Size of Items Deleted in `"C:\Windows\WinSxS`" in MB: $([math]::Round($WinsxsSizeBefore - $WinsxsSizeAfter,2))"
$Global:Result += "Total Size of Items Deleted in `"C:\Windows\WinSxS`" in MB: $([math]::Round($WinsxsSizeBefore - $WinsxsSizeAfter,2))"


Write-Host '***********************'
Write-Host 'Clear cache SCCM'

# Clear cache SCCM
Try { 
    $CacheItems = Get-WmiObject -Namespace root\ccm\SoftMgmtAgent -Query 'SELECT ContentID,Location FROM CacheInfoEx WHERE PersistInCache != 1' -ErrorAction Stop 
} 
#  Write to log in case of failure 
Catch { 
    Write-Host 'Getting SCCM Cache Info from WMI - Failed! Check if SCCM Client is Installed!' 
}

## Call Remove-CachedApplications function 
Remove-CachedApplications
 
## Call Remove-CachedApplications function 
Remove-CachedPackages
 
## Call Remove-CachedApplications function 
Remove-CachedUpdates
 
## Call Remove-OrphanedCacheItems function 
Remove-OrphanedCacheItems

Write-Host "Processing Clear cache SCCM Finished! Total Size of Items Deleted in MB: $Global:TotalSccmClearCacheDeletedSize"
$Global:Result += "Clear cache SCCM. Total Size of Items Deleted in MB: $Global:TotalSccmClearCacheDeletedSize"

Write-Host '***********************'
Write-Host '*******TOTAL***********'
$Global:Result
Write-Host '***********************'

$DiskSpaceAfter = Get-DiskSpace -comment 'After'
$DiskSpaceResult += $DiskSpaceAfter

Write-Host 'Size of system disk in GB:' $DiskSpaceAfter.'Size (GB)'
Write-Host "Total Size of Items Deleted in MB: $([math]::Round(([convert]::ToDecimal($DiskSpaceAfter.FreeSpace) - [convert]::ToDecimal($DiskSpaceBefore.FreeSpace))/1MB, 2))"
Write-Host '***********************'
$DiskSpaceResult | Format-Table Comment, 'FreeSpace (GB)', "PercentFree"
Write-Host '***********************'
Write-Host '******** End **********'
Write-Host $(Get-Date -Format dd'.'MM'.'yyyy' 'HH':'mm)
Write-Host '***********************'
Stop-Transcript
#endregion Main
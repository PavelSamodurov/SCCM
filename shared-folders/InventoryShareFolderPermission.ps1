Function GetSharedFolderPermission {
	$SharedFolderSecs = Get-WmiObject -Class Win32_LogicalShareSecuritySetting -ErrorAction SilentlyContinue
    $Objs = @() #define the empty array

    foreach ($SharedFolderSec in $SharedFolderSecs) { 
        $SharedFolder = Get-WmiObject -Class Win32_Share -ErrorAction SilentlyContinue | Where-Object { $PSItem.Name -eq $SharedFolderSec.Name}
        $SharedFolderPath = [regex]::Escape($SharedFolder.Path)
        try{
            $dir = Get-Item -Path $SharedFolderPath -ErrorAction Stop
            $acl = $dir.GetAccessControl()
            $Owner = $acl.Owner

            $SecDescriptor = $SharedFolderSec.GetSecurityDescriptor()
            foreach($DACL in $SecDescriptor.Descriptor.DACL)
            {  
                $DACLDomain = $DACL.Trustee.Domain
                $DACLName = $DACL.Trustee.Name
                if($DACLName -eq $null)
                {
                    $UserName = 'NOT_RESOLVED'
                }
                elseif($DACLDomain -ne $null)
                {
                    $UserName = "$DACLDomain\$DACLName"
                }
                else
                {
                    $UserName = "$DACLName"
                }
            
                #customize the property
                $Properties = @{'PermissionType' = "SharedPermission"
                                'SharedFolderName' = $SharedFolderSec.Name
                                'Owner' = $Owner
                                'SecurityPrincipal' = $UserName
                                'FileSystemRights' = [Security.AccessControl.FileSystemRights]`
                                $($DACL.AccessMask -as [Security.AccessControl.FileSystemRights])
                                'AccessControlType' = [Security.AccessControl.AceType]$DACL.AceType}
                $SharedACLs = New-Object -TypeName PSObject -Property $Properties
                
                $Objs += $SharedACLs
            }
        } catch {}
    }
    return $Objs|Select-Object PermissionType,SharedFolderName,Owner,SecurityPrincipal,FileSystemRights,AccessControlType
}

Function GetSharedFolderNTFSPermission {
    $SharedFolders = Get-WmiObject -Class Win32_Share -ErrorAction SilentlyContinue | Where-Object { $PSItem.Name -notin 'ADMIN$','IPC$' -and $PSItem.Name -notlike "?$"}
    $Objs = @()

    foreach($SharedFolder in $SharedFolders) {
        
        $SharedFolderPath = [regex]::Escape($SharedFolder.Path)

        try {
            $dir = Get-Item -Path $SharedFolderPath -ErrorAction Stop
            $acl = $dir.GetAccessControl()
            $Owner = $acl.Owner

            $SharedNTFSSecs = Get-WmiObject -Class Win32_LogicalFileSecuritySetting -Filter "Path='$SharedFolderPath'"
            
            $SecDescriptor = $SharedNTFSSecs.GetSecurityDescriptor()
            foreach($DACL in $SecDescriptor.Descriptor.DACL)
            {  
                $DACLDomain = $DACL.Trustee.Domain
                $DACLName = $DACL.Trustee.Name
                if($DACLName -eq $null)
                {
                    $UserName = 'NOT_RESOLVED'
                }
                elseif($DACLDomain -ne $null)
                {
                    $UserName = "$DACLDomain\$DACLName"
                }
                else
                {
                    $UserName = "$DACLName"
                }
                
                #customize the property
                $Properties = @{'PermissionType' = "NTFSPermission"
                                'SharedFolderName' = $SharedFolder.Name
                                'Owner' = $Owner
                                'SecurityPrincipal' = $UserName
                                'FileSystemRights' = [Security.AccessControl.FileSystemRights]`
                                $($DACL.AccessMask -as [Security.AccessControl.FileSystemRights])
                                'AccessControlType' = [Security.AccessControl.AceType]$DACL.AceType
                                'AccessControlFlags' = [Security.AccessControl.AceFlags]$DACL.AceFlags}
                                
                $SharedNTFSACL = New-Object -TypeName PSObject -Property $Properties
                
                $Objs += $SharedNTFSACL

            }
        }
        catch {
        }
        
    }
	return $Objs |Select-Object PermissionType,SharedFolderName,Owner,SecurityPrincipal,FileSystemRights, `
        AccessControlType,AccessControlFlags -Unique
}

$Permissions = @()
#Add SharedPermission to variable $Permissions
$Permissions += GetSharedFolderPermission

#Add NTFSPermission to variable $Permissions
$Permissions += GetSharedFolderNTFSPermission

#Added "No Shared Folders" if $Permissions is empty.
if ($Permissions.count -eq 0){
    $Properties = @{'PermissionType' = ''
                                'SharedFolderName' = 'No Shared Folders'
                                'Owner' = ''
                                'SecurityPrincipal' = ''
                                'FileSystemRights' = ''
                                'AccessControlType' = ''}
    $Permissions += New-Object -TypeName PSObject -Property $Properties
}

#region Delete events in WMI older than 180 days
$CurrentEA = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'
(Get-WmiObject -Namespace root\cimv2 -class CM_ShareFolderPermission | Where-Object {[datetime]::Parse($PSItem.TimeAddedtoWMI) -le (Get-Date).AddDays(-180)}).Delete()
$ErrorActionPreference = $CurrentEA
#endregion Delete events in WMI older than 180 days

#region Create Class if it doesn't exist in root\cimv2
$newClass = New-Object System.Management.ManagementClass ("root\cimv2", [String]::Empty, $null);
$newClass["__CLASS"] = "CM_ShareFolderPermission";
$newClass.Qualifiers.Add("Static", $true)
$newClass.Properties.Add("SharedFolderName", [System.Management.CimType]::String, $false)
$newClass.Properties["SharedFolderName"].Qualifiers.Add("Key", $true)
$newClass.Properties.Add("TimeAddedtoWMI", [System.Management.CimType]::String, $false)
$newClass.Properties["TimeAddedtoWMI"].Qualifiers.Add("Key", $true)
$newClass.Properties.Add("PermissionType", [System.Management.CimType]::String, $false)
$newClass.Properties["PermissionType"].Qualifiers.Add("Key", $true)
$newClass.Properties.Add("SecurityPrincipal", [System.Management.CimType]::String, $false)
$newClass.Properties["SecurityPrincipal"].Qualifiers.Add("Key", $true)
$newClass.Properties.Add("FileSystemRights", [System.Management.CimType]::String, $false)
$newClass.Properties["FileSystemRights"].Qualifiers.Add("Key", $true)
$newClass.Properties.Add("AccessControlType", [System.Management.CimType]::String, $false)
$newClass.Properties["AccessControlType"].Qualifiers.Add("Key", $true)
$newClass.Properties.Add("AccessControlFlags", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("Owner", [System.Management.CimType]::String, $false)
$newClass.Put()|Out-Null
#endregion Create Class if it doesn't exist in root\cimv2

#region Publish permissions to WMI
$Today = (Get-Date)

foreach ($Permission in $Permissions) {
    Set-WmiInstance -Namespace root\cimv2 -class CM_ShareFolderPermission -ErrorAction SilentlyContinue -argument @{
        SharedFolderName=$Permission.SharedFolderName
        TimeAddedtoWMI=$(Get-Date($Today) -Format dd'.'MM'.'yyyy' 'HH':'mm)
        PermissionType=$Permission.PermissionType
        SecurityPrincipal=$Permission.SecurityPrincipal
        FileSystemRights=$Permission.FileSystemRights
        AccessControlType=$Permission.AccessControlType
        AccessControlFlags=$Permission.AccessControlFlags
        Owner=$Permission.Owner
    }|Out-Null
}
#endregion Publish permissions to WMI

Write-Output 'Compliant'
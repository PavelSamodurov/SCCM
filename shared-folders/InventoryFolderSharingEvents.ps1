#region Functions
function Convert-SddlString {
  param (
      [PARAMETER(Mandatory=$True)]$SddlString
  )
  try {
      $descriptor = [System.Security.AccessControl.FileSecurity]::new()
      $descriptor.SetSecurityDescriptorSddlForm($SddlString)
      $descriptor = $descriptor.Access

      $descriptor = $descriptor | ForEach-Object { '' + $PSItem.IdentityReference + ': ' + $PSItem.AccessControlType + ' (' + $PSItem.FileSystemRights + ')' }
      $descriptor = $descriptor -join " | "
  }
  catch {
      $descriptor = $SddlString
  }
  return $descriptor
}
#endregion Functions

#region Get-Eventlog
$events = @()

$items = Get-Eventlog -LogName Security -InstanceId 5142,5143,5144

foreach ($item in $items) {
  #declare variable
  $event = "" | Select-Object Index,TimeGenerated,InstanceID,Message,SecurityID,AccountName,AccountDomain,LogonID,ObjectType,ShareName,SharePath,OldRemark,NewRemark,OldMaxUsers,NewMaxusers,OldShareFlags,NewShareFlags,OldSD,NewSD
  
  $event.Index = $item.Index
  $event.TimeGenerated = $item.TimeGenerated
  $event.InstanceID = $item.InstanceID
  $event.Message = $item.Message -split "`n" | Select-Object -First 1
  
  if ($item.InstanceID -eq '5143'){
      # parsing $item.Message for 5143
      $MessageList = $item.Message -split "`n" |
      Select-String '(.+):		(.+)' |
      ForEach-Object {
        New-Object PSObject -Property ([Ordered] @{
          "Data" = $_.Matches[0].Groups[1].Value
          "Value" = $_.Matches[0].Groups[2].Value
        })
      }

      $event.SecurityID = $MessageList[0].Value.Trim()
      $event.AccountName = $MessageList[1].Value.Trim()
      $event.AccountDomain = $MessageList[2].Value.Trim()
      $event.LogonID = $MessageList[3].Value.Trim()
      $event.ObjectType = $MessageList[4].Value.Trim()
      $event.ShareName = $MessageList[5].Value.Trim()
      $event.SharePath = $MessageList[6].Value.Trim()
      $event.OldRemark = $MessageList[7].Value.Trim()
      $event.NewRemark = $MessageList[8].Value.Trim()
      $event.OldMaxUsers = $MessageList[9].Value.Trim()
      $event.NewMaxusers = $MessageList[10].Value.Trim()
      $event.OldShareFlags = $MessageList[11].Value.Trim()
      $event.NewShareFlags = $MessageList[12].Value.Trim()
      $event.OldSD = Convert-SddlString -SddlString $($MessageList[13].Value.Trim())
      $event.NewSD = Convert-SddlString -SddlString $($MessageList[14].Value.Trim())
  } elseif ($item.InstanceID -in '5142','5144'){
      # parsing $item.Message for 5142,5144
      $MessageList = $item.Message -split "`n" |
      Select-String '(.+):		(.+)' |
      ForEach-Object {
        New-Object PSObject -Property ([Ordered] @{
          "Data" = $_.Matches[0].Groups[1].Value
          "Value" = $_.Matches[0].Groups[2].Value
        })
      }
      $event.SecurityID = $MessageList[0].Value.Trim()
      $event.AccountName = $MessageList[1].Value.Trim()
      $event.AccountDomain = $MessageList[2].Value.Trim()
      $event.LogonID = $MessageList[3].Value.Trim()
      $event.ShareName = $MessageList[4].Value.Trim()
      $event.SharePath = $MessageList[5].Value.Trim()
  }
  
  #filtering events
  $ExcludeShares = '\\*\SCCMContentLib$','\\*\SMS_DP$','\\*\SMSPKGD$','\\*\SMSSIG$','\\*\SMSPKGE$','\\*\SMS_OCM_DATACACHE'
  if ($event.SecurityID -ne 'S-1-5-18' -and $event.ShareName -notin $ExcludeShares){
      #add event in variable $events
      $events += $event
  }
}
#endregion Get-Eventlog

#region Delete events in WMI older than 180 days
$CurrentEA = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'
(Get-WmiObject -Namespace root\cimv2 -class CM_FolderSharingEvents | Where-Object {[datetime]::Parse($PSItem.TimeGenerated) -le (Get-Date).AddDays(-180)}).Delete()
$ErrorActionPreference = $CurrentEA
#endregion Delete events in WMI older than 180 days

#region Create Class if it doesn't exist in root\cimv2
$newClass = New-Object System.Management.ManagementClass ("root\cimv2", [String]::Empty, $null);
$newClass["__CLASS"] = "CM_FolderSharingEvents";
$newClass.Qualifiers.Add("Static", $true)
$newClass.Properties.Add("Index", [System.Management.CimType]::uint32, $false)
$newClass.Properties["Index"].Qualifiers.Add("Key", $true)
$newClass.Properties.Add("TimeGenerated", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("InstanceID", [System.Management.CimType]::uint32, $false)
$newClass.Properties["InstanceID"].Qualifiers.Add("Key", $true)
$newClass.Properties.Add("Message", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("SecurityID", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("AccountName", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("AccountDomain", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("LogonID", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("ObjectType", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("ShareName", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("SharePath", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("OldRemark", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("NewRemark", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("OldMaxUsers", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("NewMaxusers", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("OldShareFlags", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("NewShareFlags", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("OldSD", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("NewSD", [System.Management.CimType]::String, $false)
$newClass.Properties.Add("TimeAddedtoWMI", [System.Management.CimType]::String, $false)
$newClass.Put()|Out-Null
#endregion Create Class if it doesn't exist in root\cimv2

#region Publish events to WMI
$Today = (Get-Date)

foreach ($event in $events) {
  Set-WmiInstance -Namespace root\cimv2 -class CM_FolderSharingEvents -ErrorAction SilentlyContinue -argument @{
      Index=$event.Index
      TimeGenerated=$event.TimeGenerated
      InstanceID=$event.InstanceID
      Message=$event.Message
      SecurityID=$event.SecurityID
      AccountName=$event.AccountName
      AccountDomain=$event.AccountDomain
      LogonID=$event.LogonID
      ObjectType=$event.ObjectType
      ShareName=$event.ShareName
      SharePath=$event.SharePath
      OldRemark=$event.OldRemark
      NewRemark=$event.NewRemark
      OldMaxUsers=$event.OldMaxUsers
      NewMaxusers=$event.NewMaxusers
      OldShareFlags=$event.OldShareFlags
      NewShareFlags=$event.NewShareFlags
      OldSD=$event.OldSD
      NewSD=$event.NewSD
      TimeAddedtoWMI=$Today
  }|Out-Null
}
#endregion Publish events to WMI

Write-Output 'Compliant'
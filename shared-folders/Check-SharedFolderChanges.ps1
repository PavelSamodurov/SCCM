################################################################
#region Vaiable
$ServerInstance = "SCCM-SERVER"
$datebase = "CM_FOO"

$Global:MailContent = $null

#endregion Vaiable

################################################################
#region Functions
function Send-EmailAnonymously {
    param (
        $User = "anonymous",
        $SMTPServer = "SMTP-SERVER",
        $From = "SCCM@DOMAIN",
        [PARAMETER(Mandatory=$True)]$To,
        $Subject = "Network folders changes",
        $Body
    )

    $PWord = ConvertTo-SecureString –String "anonymous" –AsPlainText -Force

    $Creds = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList $User, $PWord

    Send-MailMessage -From $From -To $To -Subject $Subject -Body $Body -BodyAsHtml -SmtpServer $SMTPServer -Credential $Creds -Encoding utf8
  
}

#endregion Functions

################################################################
################################################################
#region Main

################################################################
#region Update CheckStatusSharedFolderPermissions
$SqlQueryCheckStatus = @"
USE $datebase
DECLARE @DateNow AS DATETIME 
SET @DateNow = GETDATE()

IF OBJECT_ID('tempdb..#TempSHAREFOLDERPERMISSION') IS NOT NULL
BEGIN
    DROP TABLE #TempSHAREFOLDERPERMISSION
END
IF OBJECT_ID('tempdb..#TempLastSHAREFOLDERPERMISSION') IS NOT NULL
BEGIN
    DROP TABLE #TempLastSHAREFOLDERPERMISSION
END
IF OBJECT_ID('tempdb..#TempCombinedSHAREFOLDERPERMISSION') IS NOT NULL
BEGIN
    DROP TABLE #TempCombinedSHAREFOLDERPERMISSION
END

SELECT
  v_GS_CM_SHAREFOLDERPERMISSION.ResourceID
  ,SharedFolderName0
  ,PermissionType0
  ,CASE SecurityPrincipal0
	WHEN N'BUILTIN\Ïîëüçîâàòåëè' THEN  'BUILTIN\Users'
	WHEN N'BUILTIN\Àäìèíèñòðàòîðû' THEN  'BUILTIN\Administrators'
	WHEN N'NT AUTHORITY\ÑÈÑÒÅÌÀ' THEN  'NT AUTHORITY\SYSTEM'
	WHEN N'Âñå' THEN  'Everyone'
	ELSE SecurityPrincipal0
  END AS SecurityPrincipal0
  ,AccessControlType0
  ,FileSystemRights0
  ,CASE
	WHEN TimeAddedtoWMI0 LIKE '%.__ %' THEN CONVERT(datetime, TimeAddedtoWMI0, 2)
	WHEN CHARINDEX ('/',TimeAddedtoWMI0) = 0 THEN CONVERT(datetime, TimeAddedtoWMI0, 105)
	ELSE CONVERT(datetime, TimeAddedtoWMI0)
	END AS TimeAddedtoWMI0
INTO #TempSHAREFOLDERPERMISSION
FROM v_GS_CM_SHAREFOLDERPERMISSION
WHERE SharedFolderName0 != 'No Shared Folders'

--Last SHAREFOLDERPERMISSION
SELECT
  tSFP.ResourceID
  ,tSFP.SharedFolderName0
  ,LASTCHECK.LastTimeAddedtoWMI0
  ,tSFP.PermissionType0
  ,tSFP.SecurityPrincipal0
  ,tSFP.AccessControlType0
  ,tSFP.FileSystemRights0
INTO #TempLastSHAREFOLDERPERMISSION
FROM #TempSHAREFOLDERPERMISSION AS tSFP
JOIN (
	SELECT 
	  sq.ResourceID
	  ,MAX(sq.TimeAddedtoWMI0) AS LastTimeAddedtoWMI0
	FROM (
		SELECT
		ResourceID
		,CASE
			  WHEN TimeAddedtoWMI0 LIKE '%.__ %' THEN CONVERT(datetime, TimeAddedtoWMI0, 2)
			  WHEN CHARINDEX ('/',TimeAddedtoWMI0) = 0 THEN CONVERT(datetime, TimeAddedtoWMI0, 105)
			  ELSE CONVERT(datetime, TimeAddedtoWMI0)
			  END AS TimeAddedtoWMI0
		FROM v_GS_CM_SHAREFOLDERPERMISSION
	) sq
	GROUP BY
	  sq.ResourceID
) LASTCHECK
  ON tSFP.ResourceID = LASTCHECK.ResourceID AND tSFP.TimeAddedtoWMI0 = LASTCHECK.LastTimeAddedtoWMI0

-- Combined SHAREFOLDERPERMISSION
SELECT
  T1.ResourceID
  ,T1.SharedFolderName0
  ,T1.LastTimeAddedtoWMI0
  ,'[Shared]' + 
    ISNULL((  
    SELECT '(' + T2.SecurityPrincipal0 + ': ' + FileSystemRights0 + CASE AccessControlType0 WHEN 'AccessDenied' THEN ' DENY' ELSE '' END + ')'
    FROM #TempLastSHAREFOLDERPERMISSION T2  
    WHERE T1.ResourceID = T2.ResourceID
		AND T1.SharedFolderName0 = T2.SharedFolderName0
		AND T1.LastTimeAddedtoWMI0 = T2.LastTimeAddedtoWMI0
		AND T2.PermissionType0 = 'SharedPermission'
		ORDER BY SecurityPrincipal0, FileSystemRights0, AccessControlType0
    FOR XML PATH ('')  
    ),'(UNKNOWN)')
  + '[NTFS]' +   
    ISNULL((  
    SELECT '(' + T2.SecurityPrincipal0 + ': ' + FileSystemRights0 + CASE AccessControlType0 WHEN 'AccessDenied' THEN ' DENY' ELSE '' END + ')'
    FROM #TempLastSHAREFOLDERPERMISSION T2  
    WHERE T1.ResourceID = T2.ResourceID
		AND T1.SharedFolderName0 = T2.SharedFolderName0
		AND T1.LastTimeAddedtoWMI0 = T2.LastTimeAddedtoWMI0
		AND T2.PermissionType0 = 'NTFSPermission'
		ORDER BY SecurityPrincipal0, FileSystemRights0, AccessControlType0
    FOR XML PATH ('')  
    ),'(UNKNOWN)') AS Permissions
INTO #TempCombinedSHAREFOLDERPERMISSION
FROM #TempLastSHAREFOLDERPERMISSION T1
GROUP BY
  ResourceID
  ,SharedFolderName0
  ,LastTimeAddedtoWMI0

--Add New Shared Folders
INSERT INTO Custom_ApprovalShareFolderPermission (ResourceID, SharedFolderName0, CheckStatus, CheckStatusTime, ChangedBy, OldPermissions, NewPermissions)
SELECT DISTINCT ResourceID, SharedFolderName0, 'New', @DateNow, 'Script', 'None', Permissions
FROM #TempCombinedSHAREFOLDERPERMISSION
WHERE NOT EXISTS (
		SELECT ResourceID
		  ,SharedFolderName0
		FROM Custom_ApprovalShareFolderPermission
		WHERE Custom_ApprovalShareFolderPermission.ResourceID = #TempCombinedSHAREFOLDERPERMISSION.ResourceID 
		 AND Custom_ApprovalShareFolderPermission.SharedFolderName0 = #TempCombinedSHAREFOLDERPERMISSION.SharedFolderName0
	)

--Delete which no longer exist
DELETE FROM Custom_ApprovalShareFolderPermission
WHERE NOT EXISTS (
		SELECT ResourceID
		  ,SharedFolderName0
		FROM #TempCombinedSHAREFOLDERPERMISSION
		WHERE Custom_ApprovalShareFolderPermission.ResourceID = #TempCombinedSHAREFOLDERPERMISSION.ResourceID 
		 AND Custom_ApprovalShareFolderPermission.SharedFolderName0 = #TempCombinedSHAREFOLDERPERMISSION.SharedFolderName0
	)

--Change Status if something has been changed
UPDATE Custom_ApprovalShareFolderPermission
SET CheckStatus = 'Modified'
  ,ChangedBy = 'Script'
  ,CheckStatusTime = @DateNow
  ,OldPermissions = NewPermissions
  ,NewPermissions = Permissions
FROM Custom_ApprovalShareFolderPermission
JOIN #TempCombinedSHAREFOLDERPERMISSION
ON #TempCombinedSHAREFOLDERPERMISSION.ResourceID = Custom_ApprovalShareFolderPermission.ResourceID
     AND #TempCombinedSHAREFOLDERPERMISSION.SharedFolderName0 = Custom_ApprovalShareFolderPermission.SharedFolderName0
WHERE #TempCombinedSHAREFOLDERPERMISSION.Permissions != Custom_ApprovalShareFolderPermission.NewPermissions

DROP TABLE #TempSHAREFOLDERPERMISSION
DROP TABLE #TempLastSHAREFOLDERPERMISSION
DROP TABLE #TempCombinedSHAREFOLDERPERMISSION
"@

$NewChangesOnSharedPermissions = Invoke-Sqlcmd -Query $SqlQueryCheckStatus -ServerInstance $ServerInstance
#endregion Update CheckStatusSharedFolderPermissions

################################################################
#region Check Folder Sharing Events
$SqlQueryFolderSharingEvents = @"
USE $datebase
SELECT 
  SharedFolderPath
  ,ComputerName
  ,ShareName
  ,ChangedBy
  ,EventTime
  ,CONVERT(varchar, EventTime, 104) + ' ' + CONVERT(varchar, EventTime, 8) AS EventTimeString
  ,EventType
FROM(
	SELECT
	  '\\' + Netbios_Name0 + '.' + Lower(Full_Domain_Name0) + '\' + SUBSTRING ( ShareName0 ,5 ,200) AS SharedFolderPath
	  ,CASE
	   WHEN Full_Domain_Name0 IS NULL THEN Netbios_Name0
	   ELSE Netbios_Name0 + '.' + Lower(Full_Domain_Name0)
	  END AS ComputerName
	  ,SUBSTRING ( ShareName0 ,5 ,200) AS ShareName
	  ,CASE
		WHEN CHARINDEX ('/',TimeGenerated0) = 0 THEN CONVERT(datetime, TimeGenerated0, 105)
		ELSE CONVERT(datetime, TimeGenerated0)
		END AS EventTime
	  ,AccountDomain0 + '\' + AccountName0 AS ChangedBy
	  ,CASE Message0
		WHEN 'A network share object was modified. ' THEN N'Modify'
		WHEN 'A network share object was deleted. ' THEN N'Delete'
		WHEN 'A network share object was added. ' THEN N'Add'
		WHEN N'Îáúåêò ñåòåâîé ïàïêè èçìåíåí. ' THEN N'Modify'
		WHEN N'Îáúåêò ñåòåâîé ïàïêè óäàëåí. ' THEN N'Delete'
		WHEN N'Îáúåêò ñåòåâîé ïàïêè äîáàâëåí. ' THEN N'Add'
		ELSE Message0
	  END AS EventType
	FROM v_GS_CM_FOLDERSHARINGEVENTS
	JOIN v_R_System
	 ON v_GS_CM_FOLDERSHARINGEVENTS.ResourceID = v_R_System.ResourceID
 ) sq
 WHERE EventTime > DATEADD(DAY,-1,GETDATE())
 ORDER BY EventTime DESC
"@

$NewFolderSharingEvents = Invoke-Sqlcmd -Query $SqlQueryFolderSharingEvents -ServerInstance $ServerInstance

if ($NewFolderSharingEvents -ne $null) {

    $NewFolderSharingEventsList = @()
    foreach ($item in $NewFolderSharingEvents) {
        $NewFolderSharingEventsList += @"
<tr>
<td class="tg-0pky">$($item.EventType)</td>
<td class="tg-0pky">$($item.EventTimeString)</td>
<td class="tg-0pky">$($item.ChangedBy)</td>
<td class="tg-0pky">$($item.ComputerName)</td>
<td class="tg-0pky">$($item.ShareName)</td>
</tr>
"@
    }
}

$BodyFolderSharingEvents = @"
<p>
  <strong>Folder Sharing Events</strong>.
</p>
<table class="tg">
  <tr>
    <th class="tg-nr0t">Event type</th>
    <th class="tg-nr0t">Event time</th>
    <th class="tg-nr0t">Changed by</th>
    <th class="tg-nr0t">Computer name</th>
    <th class="tg-nr0t">Shared folder name</th>
  </tr>
$NewFolderSharingEventsList
</table>
<br>

"@

if ($NewFolderSharingEvents -ne $null) {
  $Global:MailContent += $BodyFolderSharingEvents
}
#endregion Check Folder Sharing Events

################################################################
#region Check changes in Custom_ApprovalShareFolderPermission
$SqlQueryApprovalSharedFolder = @"
USE $datebase
SELECT
v_R_System.ResourceID
,SharedFolderName0
,CASE WHEN v_R_System.Full_Domain_Name0 IS NULL THEN UPPER(Netbios_Name0)
  ELSE UPPER(Netbios_Name0) + '.' + Lower(v_R_System.Full_Domain_Name0)
  END AS ComputerName
,CASE
WHEN SharedFolderName0 like '\\%' THEN SharedFolderName0
WHEN v_R_System.Full_Domain_Name0 IS NULL THEN  '\\' + LOWER(Netbios_Name0) + '\' + SharedFolderName0
ELSE '\\' + UPPER(Netbios_Name0) + '.' + Lower(v_R_System.Full_Domain_Name0) + '\' + SharedFolderName0
END AS [FolderPath]
,CheckStatusTime
,CheckStatus
,ChangedBy
,OldPermissions
,NewPermissions
FROM Custom_ApprovalShareFolderPermission
JOIN  v_R_System
 ON Custom_ApprovalShareFolderPermission.ResourceID = v_R_System.ResourceID
 WHERE CheckStatus IN ('New','Modified')
 AND CheckStatusTime > DATEADD(DAY,-1,GETDATE())
"@

$NewChangesOnSharedPermissions = Invoke-Sqlcmd -Query $SqlQueryApprovalSharedFolder -ServerInstance $ServerInstance

if ($NewChangesOnSharedPermissions -ne $null) {

    $SharedFolderPermissionsList = @()
    foreach ($item in $NewChangesOnSharedPermissions) {
        #region marking changes
        $newPermSharedArray = @()
        $newPermNtfsArray = @()
        $oldPermSharedArray = @()
        $oldPermNtfsArray = @()

        if ([string]::IsNullOrEmpty($item.NewPermissions)){
          $NewPermLine = 'Unknown'
        } else {
          $newPermArray = $item.NewPermissions.Replace('[','').Replace(']','').TrimStart('Shared') -Split "NTFS"
          $newPermSharedArray = $newPermArray[0].TrimStart('(').TrimEnd(')').Replace(')(','@').Split('@')
          $newPermNtfsArray = $newPermArray[1].TrimStart('(').TrimEnd(')').Replace(')(','@').Split('@')
        }

        if ([string]::IsNullOrEmpty($item.OldPermissions) -or $item.OldPermissions -eq 'Unknown'){
          $OldPermLine = 'Unknown'
        } elseif ($item.OldPermissions -eq 'None'){
          $OldPermLine = 'None'
        } else {
          $oldPermArray = $item.OldPermissions.Replace('[','').Replace(']','').TrimStart('Shared') -Split "NTFS"
          $oldPermSharedArray = $oldPermArray[0].TrimStart('(').TrimEnd(')').Replace(')(','@').Split('@')
          $oldPermNtfsArray = $oldPermArray[1].TrimStart('(').TrimEnd(')').Replace(')(','@').Split('@')
        }

        if ($newPermSharedArray.Count -ne 0) {
          $NewPermLine = '<strong>Shared</strong><br>'
          for ($i = 0; $i -lt $newPermSharedArray.Count; $i++) {
            if ($oldPermSharedArray.Contains($newPermSharedArray[$i])){
                $NewPermLine += $newPermSharedArray[$i] + '<br>'
            } else {
                $NewPermLine += '<font color="red">' + $newPermSharedArray[$i] + '</font><br>'
            }    
          }
        }

        if ($newPermNtfsArray.Count -ne 0) {
          $NewPermLine += '<strong>NTFS</strong><br>'
          for ($i = 0; $i -lt $newPermNtfsArray.Count; $i++) {
            if ($oldPermNtfsArray.Contains($newPermNtfsArray[$i])){
                $NewPermLine += $newPermNtfsArray[$i] + '<br>'
            } else {
                $NewPermLine += '<font color="red">' + $newPermNtfsArray[$i] + '</font><br>'
            }
          }
        }
        
        if ($oldPermSharedArray.Count -ne 0) {
          $OldPermLine = '<strong>Shared</strong><br>'
          for ($i = 0; $i -lt $oldPermSharedArray.Count; $i++) {
              if ($newPermSharedArray.Contains($oldPermSharedArray[$i])){
                  $OldPermLine += $oldPermSharedArray[$i] + '<br>'
              } else {
                  $OldPermLine += '<font color="red">' + $oldPermSharedArray[$i] + '</font><br>'
              }    
          }
        }

        if ($oldPermNtfsArray.Count -ne 0) {
          $OldPermLine += '<strong>NTFS</strong><br>'
          for ($i = 0; $i -lt $oldPermNtfsArray.Count; $i++) {
              if ($newPermNtfsArray.Contains($oldPermNtfsArray[$i])){
                  $OldPermLine += $oldPermNtfsArray[$i] + '<br>'
              } else {
                  $OldPermLine += '<font color="red">' + $oldPermNtfsArray[$i] + '</font><br>'
              }
          }
        }
          
        #endregion marking changes     
        $SharedFolderPermissionsList += @"
<tr>
<td class="tg-0pky">$($item.CheckStatus)</td>
<td class="tg-0pky">$($item.ComputerName)</td>
<td class="tg-0pky">$($item.SharedFolderName0)</td>
<td class="tg-0pky">$($OldPermLine)</td>
<td class="tg-0pky">$($NewPermLine)</td>
</tr>

"@        
    }
}

$BodySharedFolderPermission = @"
<p>
  <strong>Shared Folder Permissions</strong>.
</p>
<table class="tg">
  <tr>
    <th class="tg-nr0t">Approval status</th>
    <th class="tg-nr0t">Computer name</th>
	<th class="tg-nr0t">Shared folder name</th>
	<th class="tg-nr0t">Old permissions</th>
	<th class="tg-nr0t">New permissions</th>
  </tr>
$SharedFolderPermissionsList
</table>
<br>

"@

if ($NewChangesOnSharedPermissions -ne $null) {
  $Global:MailContent += $BodySharedFolderPermission
}    
#endregion Check changes in Custom_ApprovalShareFolderPermission

################################################################
# Send Mail
If ($Global:MailContent -ne $null) {
  $MailBody = @"
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8"><title></title>
    <style type="text/css">
    .tg  {border-collapse:collapse;border-spacing:0;border:none;border-color:#ccc;}
    .tg td{font-family:Arial, sans-serif;font-size:13px;padding:10px 5px;border-style:solid;border-width:0px;overflow:hidden;word-break:normal;border-color:#ccc;color:#333;background-color:#fff;}
    .tg th{font-family:Arial, sans-serif;font-size:13px;font-weight:normal;padding:10px 5px;border-style:solid;border-width:0px;overflow:hidden;word-break:normal;border-color:#ccc;color:#333;background-color:#f0f0f0;}
    .tg .tg-nr0t{background-color:#343434;color:#efefef;border-color:inherit;text-align:center;vertical-align:top}
    .tg .tg-epna{background-color:#343434;color:#ffffff;border-color:inherit;text-align:center;vertical-align:top}
    .tg .tg-0pky{border-color:inherit;text-align:left;vertical-align:top}
    </style>
  </head><body>

"@
    $MailBody += $Global:MailContent
    $MailBody += "</body></html>"

    Send-EmailAnonymously -Body $MailBody -To "MAIL@DOMAIN"
    
}

#endregion Main
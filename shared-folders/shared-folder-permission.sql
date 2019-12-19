IF OBJECT_ID('tempdb..#TempSHAREFOLDERPERMISSION') IS NOT NULL
BEGIN
    DROP TABLE #TempSHAREFOLDERPERMISSION
END

SELECT
  v_GS_CM_SHAREFOLDERPERMISSION.ResourceID
  ,CASE
    WHEN Full_Domain_Name0 IS NULL THEN Netbios_Name0
    ELSE Netbios_Name0 + '.' + Lower(Full_Domain_Name0)
    END AS [��� ����������]
  ,Operating_System_Name_and0
  ,CASE
	WHEN Operating_System_Name_and0 like '%Server%' THEN N'������'
	ELSE N'������� �������'
  END AS [��� ����������]
  ,Resource_Domain_OR_Workgr0 AS [�����]
  ,SharedFolderName0 AS [��� ������ �������]
  ,v_GS_SHARE.Description0 AS [����������]
  ,v_GS_SHARE.Path0 AS [����]
  ,Owner0 AS [��������]
  ,CASE PermissionType0
	WHEN 'NTFSPermission' THEN  'NTFS'
	WHEN 'SharedPermission' THEN  'Shared'
	ELSE PermissionType0
  END AS [��� ����������]
  ,CASE SecurityPrincipal0
	WHEN N'BUILTIN\������������' THEN  'BUILTIN\Users'
	WHEN N'BUILTIN\��������������' THEN  'BUILTIN\Administrators'
	WHEN N'NT AUTHORITY\�������' THEN  'NT AUTHORITY\SYSTEM'
	WHEN N'���' THEN  'Everyone'
	ELSE SecurityPrincipal0
  END AS [�������]
  ,CASE AccessControlType0
	WHEN 'AccessAllowed' THEN  'Allowed'
	WHEN 'AccessDenied' THEN  'Denied'
	ELSE AccessControlType0
  END AS [������]
  ,FileSystemRights0 AS [����������]
  ,AccessControlFlags0
  ,CASE
	WHEN TimeAddedtoWMI0 LIKE '%.__ %' THEN CONVERT(datetime, TimeAddedtoWMI0, 2)
	WHEN CHARINDEX ('/',TimeAddedtoWMI0) = 0 THEN CONVERT(datetime, TimeAddedtoWMI0, 105)
	ELSE CONVERT(datetime, TimeAddedtoWMI0)
	END AS [���� ��������]
INTO #TempSHAREFOLDERPERMISSION
FROM v_GS_CM_SHAREFOLDERPERMISSION
  LEFT OUTER JOIN v_R_System
   ON v_GS_CM_SHAREFOLDERPERMISSION.ResourceID=v_R_System.ResourceID
  LEFT OUTER JOIN v_GS_SHARE
   ON v_GS_CM_SHAREFOLDERPERMISSION.ResourceID=v_GS_SHARE.ResourceID AND v_GS_CM_SHAREFOLDERPERMISSION.SharedFolderName0=v_GS_SHARE.Name0

SELECT * 
FROM #TempSHAREFOLDERPERMISSION
JOIN (
	SELECT 
	  sq.ResourceID
	  ,MAX(sq.CheckTime) AS LastCheckTime
	FROM (
		SELECT
		ResourceID
		,CASE
			  WHEN TimeAddedtoWMI0 LIKE '%.__ %' THEN CONVERT(datetime, TimeAddedtoWMI0, 2)
			  WHEN CHARINDEX ('/',TimeAddedtoWMI0) = 0 THEN CONVERT(datetime, TimeAddedtoWMI0, 105)
			  ELSE CONVERT(datetime, TimeAddedtoWMI0)
			  END AS CheckTime
		FROM v_GS_CM_SHAREFOLDERPERMISSION
	) sq
	GROUP BY
	  sq.ResourceID
) LASTCHECK
  ON #TempSHAREFOLDERPERMISSION.ResourceID = LASTCHECK.ResourceID AND #TempSHAREFOLDERPERMISSION.[���� ��������] = LASTCHECK.LastCheckTime
WHERE [�����] in (@Domain)
	AND [��� ����������] like @ComputerName
	AND [��� ����������] like @PermissionType
	AND [�������] like @SecurityPrincipal
	AND [��� ������ �������] like '%' + @SharedFolderName + '%';

DROP TABLE #TempSHAREFOLDERPERMISSION
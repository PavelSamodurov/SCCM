IF OBJECT_ID('tempdb..#TempFOLDERSHARINGEVENTS') IS NOT NULL
BEGIN
    DROP TABLE #TempFOLDERSHARINGEVENTS
END

SELECT v_GS_CM_FOLDERSHARINGEVENTS.ResourceID
  ,Netbios_Name0 + '.' + Lower(Full_Domain_Name0) AS [��� ����������]
  ,Operating_System_Name_and0
  ,Resource_Domain_OR_Workgr0 AS [�����]
  ,AccountDomain0 + '\' + AccountName0 [��� ��������]
  ,InstanceID0 AS [ID �������]
  ,CASE Message0
	WHEN 'A network share object was modified. ' THEN N'���������'
	WHEN 'A network share object was deleted. ' THEN N'��������'
	WHEN 'A network share object was added. ' THEN N'��������'
	WHEN N'������ ������� ����� �������. ' THEN N'���������'
	WHEN N'������ ������� ����� ������. ' THEN N'��������'
	WHEN N'������ ������� ����� ��������. ' THEN N'��������'
	ELSE Message0
	END AS [�������]
  ,NewSD0
  ,OldSD0
  ,SUBSTRING ( ShareName0 ,5 ,200) AS [��� ����� �����]
  ,v_GS_SHARE.Description0 AS [����������]
  ,SharePath0 AS [���� ����� �����]
    ,CASE
	  WHEN CHARINDEX ('/',TimeGenerated0) = 0 THEN CONVERT(datetime, TimeGenerated0, 105)
	  ELSE CONVERT(datetime, TimeGenerated0)
	  END AS [���� �������]
INTO #TempFOLDERSHARINGEVENTS
FROM v_GS_CM_FOLDERSHARINGEVENTS
JOIN v_R_System
 ON v_GS_CM_FOLDERSHARINGEVENTS.ResourceID = v_R_System.ResourceID
LEFT OUTER JOIN v_GS_SHARE
 ON v_GS_CM_FOLDERSHARINGEVENTS.ResourceID = v_GS_SHARE.ResourceID AND SUBSTRING ( v_GS_CM_FOLDERSHARINGEVENTS.ShareName0 ,5 ,200)=v_GS_SHARE.Name0

IF (@Date = '9/9/9999 12:00:00 AM' OR @Date IS NULL)
	SELECT * 
	FROM #TempFOLDERSHARINGEVENTS
	WHERE [�����] in (@Domain)
	  AND [��� ����������] like @ComputerName
	  AND [��� ����� �����] like '%' + @SharedFolderName + '%'
	  AND [�������] in (@EventType)
ELSE 
	SELECT *
	FROM #TempFOLDERSHARINGEVENTS
	WHERE  [���� �������] > @Date
	  AND [���� �������] < dateadd(DD,1,@Date)
	  AND [�����] in (@Domain)
	  AND [��� ����������] like @ComputerName
	  AND [��� ����� �����] like '%' + @SharedFolderName + '%'
	  AND [�������] in (@EventType)

DROP TABLE #TempFOLDERSHARINGEVENTS
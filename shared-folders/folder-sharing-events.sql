IF OBJECT_ID('tempdb..#TempFOLDERSHARINGEVENTS') IS NOT NULL
BEGIN
    DROP TABLE #TempFOLDERSHARINGEVENTS
END

SELECT v_GS_CM_FOLDERSHARINGEVENTS.ResourceID
  ,Netbios_Name0 + '.' + Lower(Full_Domain_Name0) AS [Имя компьютера]
  ,Operating_System_Name_and0
  ,Resource_Domain_OR_Workgr0 AS [Домен]
  ,AccountDomain0 + '\' + AccountName0 [Кем изменено]
  ,InstanceID0 AS [ID События]
  ,CASE Message0
	WHEN 'A network share object was modified. ' THEN N'Изменение'
	WHEN 'A network share object was deleted. ' THEN N'Удаление'
	WHEN 'A network share object was added. ' THEN N'Создание'
	WHEN N'Объект сетевой папки изменен. ' THEN N'Изменение'
	WHEN N'Объект сетевой папки удален. ' THEN N'Удаление'
	WHEN N'Объект сетевой папки добавлен. ' THEN N'Создание'
	ELSE Message0
	END AS [Событие]
  ,NewSD0
  ,OldSD0
  ,SUBSTRING ( ShareName0 ,5 ,200) AS [Имя общей папки]
  ,v_GS_SHARE.Description0 AS [Примечание]
  ,SharePath0 AS [Путь общей папки]
    ,CASE
	  WHEN CHARINDEX ('/',TimeGenerated0) = 0 THEN CONVERT(datetime, TimeGenerated0, 105)
	  ELSE CONVERT(datetime, TimeGenerated0)
	  END AS [Дата события]
INTO #TempFOLDERSHARINGEVENTS
FROM v_GS_CM_FOLDERSHARINGEVENTS
JOIN v_R_System
 ON v_GS_CM_FOLDERSHARINGEVENTS.ResourceID = v_R_System.ResourceID
LEFT OUTER JOIN v_GS_SHARE
 ON v_GS_CM_FOLDERSHARINGEVENTS.ResourceID = v_GS_SHARE.ResourceID AND SUBSTRING ( v_GS_CM_FOLDERSHARINGEVENTS.ShareName0 ,5 ,200)=v_GS_SHARE.Name0

IF (@Date = '9/9/9999 12:00:00 AM' OR @Date IS NULL)
	SELECT * 
	FROM #TempFOLDERSHARINGEVENTS
	WHERE [Домен] in (@Domain)
	  AND [Имя компьютера] like @ComputerName
	  AND [Имя общей папки] like '%' + @SharedFolderName + '%'
	  AND [Событие] in (@EventType)
ELSE 
	SELECT *
	FROM #TempFOLDERSHARINGEVENTS
	WHERE  [Дата события] > @Date
	  AND [Дата события] < dateadd(DD,1,@Date)
	  AND [Домен] in (@Domain)
	  AND [Имя компьютера] like @ComputerName
	  AND [Имя общей папки] like '%' + @SharedFolderName + '%'
	  AND [Событие] in (@EventType)

DROP TABLE #TempFOLDERSHARINGEVENTS
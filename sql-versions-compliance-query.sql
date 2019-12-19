IF (OBJECT_ID('tempdb..#csv_temp') IS NOT NULL) DROP TABLE #csv_temp;

CREATE TABLE #csv_temp (
    Build VARCHAR(MAX),
	FileVersion VARCHAR(MAX),
	SQLVersion VARCHAR(MAX),
	KB VARCHAR(MAX),
	Link VARCHAR(MAX),
	UpdateName VARCHAR(MAX),
	ReleaseDate VARCHAR(MAX)
);

BULK INSERT #csv_temp
FROM 'C:\Script\SQLVersions\SqlVersions.csv'
WITH (fieldterminator = '|', rowterminator = '\n');


SELECT
  v_R_System.Netbios_Name0 AS [Netbios Name]
  ,v_R_System.Resource_Domain_OR_Workgr0 AS [Domain]
  ,MAX(SUBSTRING(System_OU_Name0,CHARINDEX('/',System_OU_Name0)+1,200)) AS [Organizational Unit]
  ,REPLACE(REPLACE(v_GS_OPERATING_SYSTEM.Caption0,'Microsoft',''),(N' Windows '),'') AS [Operating System]
  ,v_GS_SERVICE.Name0
  ,v_GS_SERVICE.StartMode0 'ServiceStartMode'
  ,v_GS_SERVICE.StartName0 AS [Log On As]
  ,v_GS_SERVICE.DisplayName0 'ServiceName'
 ,CASE
    WHEN v_GS_SERVICE.DisplayName0 = 'SQL Server (MSSQLSERVER)'
    THEN 'Default'
    ELSE REPLACE(SUBSTRING(v_GS_SERVICE.DisplayName0,CHARINDEX('(',v_GS_SERVICE.DisplayName0)+1,LEN(v_GS_SERVICE.DisplayName0)),')','')
  END AS [Instance]
  ,v_GS_SERVICE.PathName0
  ,CASE
    WHEN v_GS_SERVICE.PathName0 like '%\MSSQL10_50%'
    THEN 'SQL Server 2008 R2'
    WHEN v_GS_SERVICE.PathName0 like '%\MSSQL10%'
    THEN 'SQL Server 2008'
    WHEN v_GS_SERVICE.PathName0 like '%\MSSQL11%'
    THEN 'SQL Server 2012'
    WHEN v_GS_SERVICE.PathName0 like '%\MSSQL12%'
    THEN 'SQL Server 2014'
    WHEN v_GS_SERVICE.PathName0 like '%\MSSQL13%'
    THEN 'SQL Server 2016'
    WHEN v_GS_SERVICE.PathName0 like '%\MSSQL14%'
    THEN 'SQL Server 2017'
    ELSE 'Unknown'
  END AS [SQL Version]
  ,v_GS_SoftwareFile.FileVersion --FileVersion from DataBase
  ,CASE
    WHEN v_GS_SoftwareFile.FileVersion like '%(%)%'
     THEN REPLACE(LEFT(v_GS_SoftwareFile.FileVersion,CHARINDEX(' (',v_GS_SoftwareFile.FileVersion)-1),'.0','.')
    ELSE v_GS_SoftwareFile.FileVersion
  END AS  [SQL File Version]
  ,CONVERT(VARCHAR, FORMAT((vSMS_CombinedDeviceResources.LastSoftwareScan + '03:00'), 'dd.MM.yyyy HH:mm', 'ru-RU')) AS [Last Software Scan]
  ,ActualVer.FileVersion AS [Actual File Version]
  ,ActualVer.Build AS [Actual Build]
  ,ActualVer.KB
  ,ActualVer.UpdateName AS [Update Name]
  ,ActualVer.Link
  ,CONVERT(datetime, ActualVer.ReleaseDate) AS [Release Date]
FROM v_R_System
JOIN v_GS_COMPUTER_SYSTEM
 ON v_GS_COMPUTER_SYSTEM.ResourceID = v_R_System.ResourceID
LEFT OUTER JOIN v_RA_System_SystemOUName
 ON v_R_System.ResourceID = v_RA_System_SystemOUName.ResourceID
JOIN   v_GS_SERVICE
 ON v_R_System.ResourceID = v_GS_SERVICE.ResourceID
JOIN   v_GS_OPERATING_SYSTEM
 ON v_GS_OPERATING_SYSTEM.ResourceID = v_R_System.ResourceID
JOIN   v_GS_SoftwareFile
 ON v_GS_SoftwareFile.FilePath+v_GS_SoftwareFile.FileName = SUBSTRING(LEFT(v_GS_SERVICE.PathName0,CHARINDEX('" -s',v_GS_SERVICE.PathName0)-1),2,LEN(LEFT(v_GS_SERVICE.PathName0,CHARINDEX('" -s',v_GS_SERVICE.PathName0)-1)))
 AND v_GS_SoftwareFile.ResourceID = v_GS_SERVICE.ResourceID
LEFT OUTER JOIN vSMS_CombinedDeviceResources
 ON v_R_System.ResourceID = vSMS_CombinedDeviceResources.MachineID
LEFT OUTER JOIN (
	SELECT
	  Build
	  ,FileVersion
	  ,SQLVersion
	  ,KB
	  ,Link
	  ,UpdateName
	  ,ReleaseDate
	  ,DENSE_RANK() OVER (PARTITION BY SQLVersion ORDER BY FileVersion DESC) AS rn
	FROM #csv_temp
    WHERE UpdateName NOT LIKE '%Beta%'
) ActualVer
 ON SUBSTRING(v_GS_SoftwareFile.FileVersion,1,4) = ActualVer.SQLVersion
 AND ActualVer.rn = '1'
WHERE
  v_GS_SERVICE.DisplayName0 like 'SQL Server (%'
  AND v_R_System.Operating_System_Name_and0 like '%Server%'
GROUP BY
  v_R_System.Netbios_Name0
  ,v_R_System.Resource_Domain_OR_Workgr0
  ,v_GS_OPERATING_SYSTEM.Caption0
  ,v_GS_SERVICE.Name0
  ,v_GS_SERVICE.StartMode0
  ,v_GS_SERVICE.StartName0
  ,v_GS_SERVICE.DisplayName0
  ,v_GS_SERVICE.PathName0
  ,v_GS_SoftwareFile.FileVersion
  ,vSMS_CombinedDeviceResources.LastSoftwareScan
  ,ActualVer.FileVersion
  ,ActualVer.Build
  ,ActualVer.KB
  ,ActualVer.UpdateName
  ,ActualVer.Link
  ,ActualVer.ReleaseDate
  ,ActualVer.SQLVersion
ORDER BY
  ActualVer.SQLVersion
  ,v_R_System.Netbios_Name0

DROP TABLE #csv_temp
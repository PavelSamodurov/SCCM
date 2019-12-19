IF OBJECT_ID('tempdb..#TempRhelUpdateInfoXml') IS NOT NULL DROP TABLE #TempRhelUpdateInfoXml
IF OBJECT_ID('tempdb..#TempXmlUpdates') IS NOT NULL DROP TABLE #TempXmlUpdates
IF OBJECT_ID('tempdb..#TempRhelUpdates') IS NOT NULL DROP TABLE #TempRhelUpdates
IF OBJECT_ID('tempdb..#TempFileRelease') IS NOT NULL DROP TABLE #TempFileRelease
IF OBJECT_ID('tempdb..#TempCveInfo') IS NOT NULL DROP TABLE #TempCveInfo
IF OBJECT_ID('tempdb..#TempRhelUpdatesLatest') IS NOT NULL DROP TABLE #TempRhelUpdatesLatest

CREATE TABLE #TempRhelUpdateInfoXml ( updateinfoXML XML )
DECLARE @URL VARCHAR(MAX) 
SELECT @URL = 'http://RHEL_REPOSITORY/repodata/updateinfo.xml' 

DECLARE @Response varchar(MAX)
DECLARE @XML xml
DECLARE @Obj int 
DECLARE @Result int 
DECLARE @HTTPStatus int 
DECLARE @ErrorMsg varchar(MAX)

EXEC @Result = sp_OACreate 'MSXML2.XMLHttp', @Obj OUT 

EXEC @Result = sp_OAMethod @Obj, 'open', NULL, 'GET', @URL, false
EXEC @Result = sp_OAMethod @Obj, 'setRequestHeader', NULL, 'Content-Type', 'application/x-www-form-urlencoded'
EXEC @Result = sp_OAMethod @Obj, send, NULL, ''
EXEC @Result = sp_OAGetProperty @Obj, 'status', @HTTPStatus OUT 

INSERT #TempRhelUpdateInfoXml ( updateinfoXML )
EXEC @Result = sp_OAGetProperty @Obj, 'responseXML.xml'--, @Response OUT 

DECLARE @XmlUpdates XML
SET @XmlUpdates = (SELECT * FROM #TempRhelUpdateInfoXml)

SELECT x.items.query('.') AS [Update]
INTO #TempXmlUpdates
FROM @XmlUpdates.nodes('/updates/update') as x(items) 

SELECT DISTINCT
  A.Casted.value(N'/update[1]/@status',N'nvarchar(250)') AS [Status]
  ,A.Casted.value(N'/update[1]/@type',N'nvarchar(250)') AS [Type]
  ,A.Casted.value(N'/update[1]/id[1]',N'nvarchar(250)') AS [Id]
  ,A.Casted.value(N'/update[1]/title[1]',N'nvarchar(250)') AS [Title]
  ,A.Casted.value(N'/update[1]/issued[1]/@date',N'nvarchar(250)') AS [Date]
  ,Software.value(N'@name',N'nvarchar(250)') AS [Name]
  ,Software.value(N'@version',N'nvarchar(250)') AS [Version]
  ,Software.value(N'@release',N'nvarchar(250)') AS [Release]
  ,REPLACE(REPLACE(REPLACE(REPLACE(Software.value(N'filename[1]',N'nvarchar(250)'),'.x86_64',''),'.i686',''),'.noarch',''),'.rpm','') AS [FileName]
INTO #TempRhelUpdates
FROM #TempXmlUpdates AS u
OUTER APPLY (SELECT CAST(u.[Update] AS XML)) AS A(Casted)
OUTER APPLY A.Casted.nodes(N'/update/pkglist/collection/package') AS B(Software);

SELECT DISTINCT
  A.Casted.value(N'/update[1]/issued[1]/@date',N'nvarchar(250)') AS [ReleaseDate]
  ,REPLACE(REPLACE(REPLACE(REPLACE(Software.value(N'filename[1]',N'nvarchar(250)'),'.x86_64',''),'.i686',''),'.noarch',''),'.rpm','') AS [FileName]
  ,Software.value(N'@name',N'nvarchar(250)') AS [Name]
INTO #TempFileRelease
FROM #TempXmlUpdates AS u
OUTER APPLY (SELECT CAST(u.[Update] AS XML)) AS A(Casted)
OUTER APPLY A.Casted.nodes(N'/update/pkglist/collection/package') AS B(Software)

SELECT DISTINCT
  u.Name
  ,u.Date AS CveClosingDate
  ,cve.CVE
  ,cve.CveLink
INTO #TempCveInfo
FROM #TempRhelUpdates u
JOIN (
    SELECT
    A.Casted.value(N'/update[1]/id[1]',N'nvarchar(20)') AS [Id]
    ,Reference.value(N'@id',N'nvarchar(50)') AS [CVE]
    --,Reference.value(N'@title',N'nvarchar(50)') AS [RefTitle]
    ,Reference.value(N'@href',N'nvarchar(250)') AS [CveLink]
    FROM #TempXmlUpdates AS u
    OUTER APPLY (SELECT CAST(u.[Update] AS XML)) AS A(Casted)
    OUTER APPLY A.Casted.nodes(N'/update/references/reference') AS C(Reference)
) cve
ON u.Id = cve.Id AND cve.CVE LIKE 'CVE%'


SELECT
  u.Name
  ,u.Status
  ,u.Type
  ,u.Id
  ,u.Title
  ,u.Version + '-' + u.Release AS ActualVersion
  ,u.Version
  ,lastupd.Date AS ReleaseDate
  ,u.FileName
INTO #TempRhelUpdatesLatest
FROM #TempRhelUpdates u
JOIN (
	SELECT
	 MAX(Date) AS Date
	 ,Name
	FROM #TempRhelUpdates
	GROUP BY
	 Name
) lastupd
ON u.Name = lastupd.Name 
 AND u.Date = lastupd.Date


SELECT
  v_R_System.ResourceID
  ,v_R_System.Netbios_Name0
  ,TimeStamp
  ,REPLACE(REPLACE(REPLACE(v_GS_ADD_REMOVE_PROGRAMS.DisplayName0,'.x86_64',''),'.i686',''),'.noarch','') AS DisplayName0
  ,SUBSTRING(v_GS_ADD_REMOVE_PROGRAMS.DisplayName0,0,CHARINDEX(Version0,v_GS_ADD_REMOVE_PROGRAMS.DisplayName0,0)-1) AS Name
  ,REPLACE(REPLACE(REPLACE(RIGHT(v_GS_ADD_REMOVE_PROGRAMS.DisplayName0,LEN(v_GS_ADD_REMOVE_PROGRAMS.DisplayName0) - CHARINDEX(Version0,v_GS_ADD_REMOVE_PROGRAMS.DisplayName0,0) + 1),'.x86_64',''),'.i686',''),'.noarch','') AS CurrentVersion
  ,InstallDate0
  ,CONVERT(datetime, SUBSTRING(InstallDate0,0,9)) [Install Date]
  ,Publisher0
  ,Version0
  ,actver.ActualVersion
  ,actver.FileName AS ActualFileName
  ,CASE
    WHEN actver.Name IS NULL THEN NULL
    WHEN REPLACE(REPLACE(REPLACE(v_GS_ADD_REMOVE_PROGRAMS.DisplayName0,'.x86_64',''),'.i686',''),'.noarch','') != actver.FileName THEN '1'
    ELSE '0'
   END AS [Update Required]
  ,actver.Id
  ,actver.Status
  ,actver.Type
  ,actver.Title
  ,CONVERT(datetime, SUBSTRING(actver.ReleaseDate,0,11)) [ReleaseDate]
  ,CONVERT(datetime, SUBSTRING(filerelease.ReleaseDate,0,11)) [CurrentFileReleaseDate]
  ,cve.CVE
  ,cve.CveLink
  ,CONVERT(datetime, SUBSTRING(cve.CveClosingDate,0,11)) [CveClosingDate]
  ,CASE
	WHEN cve.CVE IS NULL THEN NULL
    WHEN filerelease.ReleaseDate < cve.CveClosingDate THEN '1'
    ELSE '0'
  END AS [CveIsOpen]
  ,DENSE_RANK() OVER (PARTITION BY SUBSTRING(v_GS_ADD_REMOVE_PROGRAMS.DisplayName0,0,CHARINDEX(Version0,v_GS_ADD_REMOVE_PROGRAMS.DisplayName0,0)-1), Netbios_Name0 ORDER BY CONVERT(datetime, SUBSTRING(filerelease.ReleaseDate,0,11)) DESC) AS [CurrentVersionRank]
FROM v_R_System
JOIN v_GS_ADD_REMOVE_PROGRAMS
 ON v_R_System.ResourceID = v_GS_ADD_REMOVE_PROGRAMS.ResourceID 
 AND v_R_System.AgentEdition0 = '13'
LEFT JOIN #TempRhelUpdatesLatest actver
 ON SUBSTRING(v_GS_ADD_REMOVE_PROGRAMS.DisplayName0,0,CHARINDEX(Version0,v_GS_ADD_REMOVE_PROGRAMS.DisplayName0,0)-1) = actver.Name
LEFT JOIN #TempFileRelease filerelease
 ON REPLACE(REPLACE(REPLACE(v_GS_ADD_REMOVE_PROGRAMS.DisplayName0,'.x86_64',''),'.i686',''),'.noarch','') = filerelease.FileName
LEFT JOIN #TempCveInfo cve
 ON actver.Name = cve.Name

DROP TABLE #TempRhelUpdateInfoXml
DROP TABLE #TempXmlUpdates
DROP TABLE #TempRhelUpdates
DROP TABLE #TempFileRelease
DROP TABLE #TempCveInfo
DROP TABLE #TempRhelUpdatesLatest
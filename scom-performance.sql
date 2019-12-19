IF OBJECT_ID('tempdb..#TempPerformance') IS NOT NULL
BEGIN
    DROP TABLE #TempPerformance
END

SELECT
  (Perf.vPerfHourly.DateTime + '03:00:00') AS [DateTime]
  ,DATEADD(DAY, DATEDIFF(DAY, 0, DateTime + '03:00:00'), 0) AS [DateTimeDay]
  ,Perf.vPerfHourly.AverageValue
  ,Perf.vPerfHourly.MinValue
  ,Perf.vPerfHourly.MaxValue
  ,vPerformanceRuleInstance.InstanceName
  ,vPerformanceRule.ObjectName
  ,vPerformanceRule.CounterName
  ,vme2.Name AS [NetbiosName]
  ,CASE
	WHEN CHARINDEX('.',vme2.Name) = '0' THEN 'None'
	ELSE SUBSTRING(vme2.Name,CHARINDEX('.',vme2.Name)+1,LEN(vme2.Name)-CHARINDEX('.',vme2.Name))
  END AS [Domain]
  ,CASE
    WHEN vme2.FullName LIKE 'Microsoft.Windows%' AND vme2.Name LIKE 'W%' THEN 'Windows WKS'
    WHEN vme2.FullName LIKE 'Microsoft.Windows%' THEN 'Windows Server'
    WHEN CHARINDEX('.',vme2.FullName,CHARINDEX('.',vme2.FullName)+1) = '0' AND CHARINDEX('.',vme2.FullName) = '0' THEN 'Unknown'
    ELSE SUBSTRING(SUBSTRING(vme2.FullName,CHARINDEX('.',vme2.FullName)+1,LEN(vme2.FullName)-CHARINDEX('.',vme2.FullName)),0,CHARINDEX('.',SUBSTRING(vme2.FullName,CHARINDEX('.',vme2.FullName)+1,LEN(vme2.FullName)-CHARINDEX('.',vme2.FullName))))
  END AS [Device]
INTO #TempPerformance
FROM
  vPerformanceRule
  INNER JOIN vPerformanceRuleInstance
    ON vPerformanceRule.RuleRowId = vPerformanceRuleInstance.RuleRowId
  INNER JOIN Perf.vPerfHourly
    ON vPerformanceRuleInstance.PerformanceRuleInstanceRowId = Perf.vPerfHourly.PerformanceRuleInstanceRowId
  INNER JOIN vManagedEntity vme
    ON Perf.vPerfHourly.ManagedEntityRowId = vme.ManagedEntityRowId
  INNER JOIN vManagedEntity vme2
    ON vme2.ManagedEntityRowId = vme.TopLevelHostManagedEntityRowId
WHERE CounterName IN ('PercentMemoryUsed','% Used Memory','Free Memory %','% Processor Time','% Free Space','Used Percentage','Disk - /var Used (%)','Current Disk Queue Length','Bytes Total/sec','Interface Received Bytes Rate','Interface Transmitted Bytes Rate')
AND Perf.vPerfHourly.DateTime > (GETDATE() - 30)

SELECT DISTINCT
  #TempPerformance.[DateTime]
  ,#TempPerformance.[DateTimeDay]
  ,#TempPerformance.NetbiosName
  ,#TempPerformance.Domain
  ,#TempPerformance.Device
  ,CASE
    WHEN Memory.CounterName = 'Free Memory %' THEN (100 - Memory.AverageValue)
    ELSE Memory.AverageValue
  END AS [MemoryAverage]
  ,CASE
    WHEN Memory.CounterName = 'Free Memory %' THEN (100 - Memory.MinValue)
    ELSE Memory.MaxValue
  END AS [MemoryMax]
  ,CASE
    WHEN Memory.CounterName = 'Free Memory %' THEN (100 - Memory.MaxValue)
    ELSE Memory.MinValue
  END AS [MemoryMin]
  ,CPU.AverageValue AS [CPUAverage]
  ,CPU.MaxValue AS [CPUMax]
  ,CPU.MinValue AS [CPUMin]
  ,CASE OtherCounter.CounterName
	  WHEN '% Free Space' THEN (100 - OtherCounter.MinValue)
    WHEN 'Used Percentage' THEN OtherCounter.MaxValue
    WHEN 'Disk - /var Used (%)' THEN OtherCounter.MaxValue
	WHEN 'Bytes Total/sec' THEN (OtherCounter.MinValue*8/(1024*1024))
    WHEN 'Interface Received Bytes Rate' THEN (OtherCounter.MinValue*8/(1024*1024))
    WHEN 'Interface Transmitted Bytes Rate' THEN (OtherCounter.MinValue*8/(1024*1024))
	  ELSE OtherCounter.MaxValue
    END AS [OtherCounterMax]
  ,CASE OtherCounter.CounterName
      WHEN '% Free Space' THEN (100 - OtherCounter.MaxValue)
      WHEN 'Used Percentage' THEN OtherCounter.MinValue
      WHEN 'Disk - /var Used (%)' THEN OtherCounter.MinValue
	  WHEN 'Bytes Total/sec' THEN (OtherCounter.MinValue*8/(1024*1024))
      WHEN 'Interface Received Bytes Rate' THEN (OtherCounter.MinValue*8/(1024*1024))
      WHEN 'Interface Transmitted Bytes Rate' THEN (OtherCounter.MinValue*8/(1024*1024))
	  ELSE OtherCounter.MinValue
    END AS [OtherCounterMin]
   ,CASE OtherCounter.CounterName
      WHEN '% Free Space' THEN (100 - OtherCounter.AverageValue)
      WHEN 'Used Percentage' THEN OtherCounter.AverageValue
      WHEN 'Disk - /var Used (%)' THEN OtherCounter.AverageValue
	    WHEN 'Bytes Total/sec' THEN (OtherCounter.MinValue*8/(1024*1024))
      WHEN 'Interface Received Bytes Rate' THEN (OtherCounter.MinValue*8/(1024*1024))
      WHEN 'Interface Transmitted Bytes Rate' THEN (OtherCounter.MinValue*8/(1024*1024))
	  ELSE OtherCounter.AverageValue
    END AS [OtherCounterAverage]
  ,OtherCounter.ObjectName AS [OtherCounterObjectName]
  ,CASE OtherCounter.CounterName
	WHEN '% Free Space' THEN '% Used Space'
    WHEN 'Used Percentage' THEN '% Used Space'
    WHEN 'Disk - /var Used (%)' THEN '% Used Space'
	WHEN 'Bytes Total/sec' THEN 'Mbit/sec'
    WHEN 'Interface Received Bytes Rate' THEN 'Mbit/sec'
    WHEN 'Interface Transmitted Bytes Rate' THEN 'Mbit/sec'
	  ELSE OtherCounter.CounterName
    END AS [OtherCounterCounterName]
  ,CASE
	WHEN OtherCounter.InstanceName LIKE '%/0/1' AND OtherCounter.CounterName = 'Interface Received Bytes Rate' THEN 'Management Interface (Received)'
	WHEN OtherCounter.InstanceName LIKE '%/0/1' AND OtherCounter.CounterName = 'Interface Transmitted Bytes Rate' THEN 'Management Interface (Transmitted)'
	WHEN OtherCounter.InstanceName LIKE '%/1/1' AND OtherCounter.CounterName = 'Interface Received Bytes Rate' THEN 'Data Interface (Received)'
	WHEN OtherCounter.InstanceName LIKE '%/1/1' AND OtherCounter.CounterName = 'Interface Transmitted Bytes Rate' THEN 'Data Interface (Transmitted)'
    ELSE OtherCounter.InstanceName
  END AS [OtherCounterInstanceName]
  ,CASE
    WHEN UsedSpaceSystemDisk.CounterName = 'Disk - /var Used (%)' THEN UsedSpaceSystemDisk.MaxValue
    ELSE (100 - UsedSpaceSystemDisk.MinValue)
  END AS [UsedSystemDiskMax]
  ,NetworkFirstAdapter.AverageValue*8/(1024*1024) AS [NetworkFirstAdapterAverage]
  ,NetworkFirstAdapter.MaxValue*8/(1024*1024) AS [NetworkFirstAdapterMax]
FROM #TempPerformance
 LEFT OUTER JOIN #TempPerformance AS Memory
  ON #TempPerformance.DateTime = Memory.DateTime
   AND #TempPerformance.NetbiosName = Memory.NetbiosName
   AND Memory.ObjectName = 'Memory'
   AND Memory.CounterName IN ('PercentMemoryUsed','% Used Memory','Free Memory %')
 LEFT OUTER JOIN #TempPerformance AS CPU
  ON #TempPerformance.DateTime = CPU.DateTime
   AND #TempPerformance.NetbiosName = CPU.NetbiosName
   AND CPU.ObjectName IN ('Processor Information','Processor')
   AND CPU.CounterName = '% Processor Time'

 LEFT OUTER JOIN #TempPerformance AS OtherCounter
  ON #TempPerformance.DateTime = OtherCounter.DateTime
   AND #TempPerformance.NetbiosName = OtherCounter.NetbiosName
   AND OtherCounter.CounterName IN ('% Free Space','Used Percentage','Disk - /var Used (%)','Current Disk Queue Length','Bytes Total/sec','Interface Received Bytes Rate','Interface Transmitted Bytes Rate')
   AND OtherCounter.InstanceName NOT LIKE '%/LO/1'
 
 LEFT OUTER JOIN #TempPerformance AS UsedSpaceSystemDisk
  ON #TempPerformance.DateTime = UsedSpaceSystemDisk.DateTime
   AND #TempPerformance.NetbiosName = UsedSpaceSystemDisk.NetbiosName
   --AND UsedSpaceSystemDisk.ObjectName = 'LogicalDisk'
   AND (
     UsedSpaceSystemDisk.CounterName = '% Free Space' AND UsedSpaceSystemDisk.InstanceName IN ('C:','/')
     OR UsedSpaceSystemDisk.CounterName = 'Disk - /var Used (%)'
   )
  LEFT OUTER JOIN (
	SELECT
	 [DateTime]
     ,[DateTimeDay]
	 ,NetbiosName
	 ,MaxValue
	 ,AverageValue
	 ,InstanceName
	 ,DENSE_RANK() OVER (PARTITION BY NetbiosName ORDER BY InstanceName) AS rn
	FROM #TempPerformance
	WHERE #TempPerformance.ObjectName = 'Network Adapter'
      AND #TempPerformance.CounterName = 'Bytes Total/sec'
  UNION ALL
  SELECT
  	[DateTime]
    ,[DateTimeDay]
	,NetbiosName
	,SUM(MaxValue) AS MaxValue
	,SUM(AverageValue) AS AverageValue
	,InstanceName
    ,'1' AS rn
  FROM #TempPerformance
  WHERE CounterName IN ('Interface Received Bytes Rate','Interface Transmitted Bytes Rate')
    AND InstanceName like '%/1/1'
  GROUP BY
    [DateTime]
    ,[DateTimeDay]
	,NetbiosName
    ,InstanceName
  ) NetworkFirstAdapter
   ON #TempPerformance.DateTime = NetworkFirstAdapter.DateTime
   AND #TempPerformance.NetbiosName = NetworkFirstAdapter.NetbiosName
   AND NetworkFirstAdapter.rn = '1'
--ORDER BY DateTime

DROP TABLE #TempPerformance
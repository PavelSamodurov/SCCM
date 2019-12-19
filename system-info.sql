SELECT
  v_R_System.ResourceID
  ,Netbios_Name0
  ,Netbios_Name0 + (CASE WHEN Full_Domain_Name0 IS NOT NULL THEN '.' + LOWER(Full_Domain_Name0) ELSE '' END) AS Netbios_DomainName
  ,LOWER(Full_Domain_Name0) AS Domain
  ,Resource_Domain_OR_Workgr0
  ,User_Domain0 + '\' + User_Name0 AS PrimaryUser
  --IPAddress for v_R_System
  ,STUFF(
      (SELECT CHAR(10) 
      + CASE
      WHEN CHARINDEX(',', IPAddress0) = 0 THEN IPAddress0
      ELSE SUBSTRING(IPAddress0,0,CHARINDEX(',', IPAddress0))
      END
      FROM v_GS_NETWORK_ADAPTER_CONFIGURATION
      WHERE v_R_System.ResourceID = v_GS_NETWORK_ADAPTER_CONFIGURATION.ResourceID
      AND v_GS_NETWORK_ADAPTER_CONFIGURATION.IPAddress0 IS NOT NULL
      ORDER BY IPAddress0
      FOR XML PATH ('')
  ),1,1,'') AS IPAddress
  --END IPAddress for v_R_System
  --MACAddress for v_R_System
  ,STUFF(
      (SELECT CHAR(10)
      + MACAddress0
      FROM v_GS_NETWORK_ADAPTER_CONFIGURATION
      WHERE v_R_System.ResourceID = v_GS_NETWORK_ADAPTER_CONFIGURATION.ResourceID
      AND v_GS_NETWORK_ADAPTER_CONFIGURATION.IPAddress0 IS NOT NULL
      ORDER BY IPAddress0
      FOR XML PATH ('')
  ),1,1,'') AS MACAddress
  --END MACAddress for v_R_System
  --Logical Disks for v_R_System
  ,STUFF(
      (SELECT CHAR(10) 
      + CONVERT(varchar,CEILING(v_GS_DISK.Size0 / 1024.0)) + 'GB'
      FROM v_GS_DISK
      WHERE v_R_System.ResourceID = v_GS_DISK.ResourceID
      ORDER BY v_GS_DISK.Index0
      FOR XML PATH ('')
  ),1,1,'') AS Disks
  --END Logical Disks for v_R_System
  ,CASE
      WHEN (SELECT TOP 1 'TRUE' FROM v_GS_NETWORK_ADAPTER_CONFIGURATION NetAd WHERE v_R_System.ResourceID = NetAd.ResourceID AND NetAd.Description0 LIKE '%Wi-Fi%') = 'TRUE' THEN 'Yes'
      ELSE 'No' END AS [haveWiFi]
  ,(CASE WHEN v_GS_PROCESSOR.Name0 LIKE 'AMD%' THEN 'AMD' ELSE SUBSTRING(v_GS_PROCESSOR.Name0,CHARINDEX('@',v_GS_PROCESSOR.Name0) + 2,7) END) 
      + ' (Cores:' + CONVERT(varchar,v_GS_PROCESSOR.NumberOfCores0 * (SELECT COUNT(*) FROM v_GS_PROCESSOR WHERE v_GS_PROCESSOR.ResourceID = v_R_System.ResourceID)) + ')' AS [CPU]
  ,CONVERT(varchar,CEILING(v_GS_X86_PC_MEMORY.TotalPhysicalMemory0 / 1024.0 / 1024.0)) + 'GB' AS [Memory]
  ,v_GS_PC_BIOS.SerialNumber0
  ,(CASE
        WHEN v_GS_OPERATING_SYSTEM.Caption0 LIKE 'Red Hat%' THEN 'RHEL '
        WHEN v_GS_OPERATING_SYSTEM.Caption0 LIKE '%Server%' THEN 'Windows Server '
        ELSE 'Windows ' END)
        + SUBSTRING(v_GS_OPERATING_SYSTEM.Caption0
          ,(PATINDEX('%[0-9]%',v_GS_OPERATING_SYSTEM.Caption0))
          ,PATINDEX('%[0-9] %',v_GS_OPERATING_SYSTEM.Caption0) - PATINDEX('%[0-9]%',v_GS_OPERATING_SYSTEM.Caption0)+1
          )
        + (CASE WHEN v_GS_OPERATING_SYSTEM.Caption0 LIKE '%R2%' THEN ' R2' ELSE '' END)
        + (CASE WHEN Build LIKE '10%' THEN ' (' + vSMS_WindowsServicingLocalizedNames.Value + ')' ELSE '' END) AS OS
  ,REPLACE(REPLACE(v_GS_OPERATING_SYSTEM.Caption0,'Microsoft ',''), N'Майкрософт ','')
      + (CASE WHEN Build LIKE '10%' THEN ' (' + vSMS_WindowsServicingLocalizedNames.Value + ')' ELSE '' END)
      +  ' ' + (CASE v_GS_SYSTEM.SystemType0	WHEN 'X64-based PC' THEN 'x64' ELSE 'x86'END) AS OSVer
  ,Operating_System_Name_and0
  ,v_GS_OPERATING_SYSTEM.Version0
  ,OSLanguage0
  ,v_GS_OPERATING_SYSTEM.InstallDate0
  ,LastBootUpTime0
FROM v_R_System
LEFT JOIN v_GS_OPERATING_SYSTEM
 ON v_R_System.ResourceID = v_GS_OPERATING_SYSTEM.ResourceID
LEFT JOIN vSMS_WindowsServicingStates
 ON v_GS_OPERATING_SYSTEM.Version0=vSMS_WindowsServicingStates.Build
 AND vSMS_WindowsServicingStates.Branch = '0'
LEFT JOIN vSMS_WindowsServicingLocalizedNames
 ON vSMS_WindowsServicingStates.Name = vSMS_WindowsServicingLocalizedNames.Name
 AND vSMS_WindowsServicingLocalizedNames.LocaleID = 1033
LEFT OUTER JOIN v_GS_PROCESSOR
 ON v_R_System.ResourceID = v_GS_PROCESSOR.ResourceID
LEFT OUTER JOIN v_GS_X86_PC_MEMORY
 ON v_R_System.ResourceID = v_GS_X86_PC_MEMORY.ResourceID
LEFT OUTER JOIN v_GS_PC_BIOS
 ON v_R_System.ResourceID = v_GS_PC_BIOS.ResourceID
LEFT JOIN v_GS_SYSTEM
 ON v_R_System.ResourceID = v_GS_SYSTEM.ResourceID
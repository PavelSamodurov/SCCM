SELECT DISTINCT
v_R_System.ResourceID
,Netbios_Name0
,Netbios_Name0 + (CASE WHEN v_R_System.Full_Domain_Name0 IS NOT NULL THEN '.' + LOWER(v_R_System.Full_Domain_Name0) ELSE '' END) AS Netbios_DomainName
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
    + '[' + v_GS_LOGICAL_DISK.VolumeName0 + '] ' + CONVERT(varchar,CEILING(v_GS_LOGICAL_DISK.Size0 / 1024.0)) + 'GB'
    FROM v_GS_LOGICAL_DISK
    WHERE v_R_System.ResourceID = v_GS_LOGICAL_DISK.ResourceID
    ORDER BY v_GS_LOGICAL_DISK.VolumeName0
    FOR XML PATH ('')
),1,1,'') AS Volumes
,STUFF(
    (SELECT CHAR(10)
    + '[' + v_GS_LOGICAL_DISK.VolumeName0 + '] ' + FORMAT(v_GS_LOGICAL_DISK.FreeSpace0 / 1024.0, 'N1', 'en-us') + 'GB'
    FROM v_GS_LOGICAL_DISK
    WHERE v_R_System.ResourceID = v_GS_LOGICAL_DISK.ResourceID
    ORDER BY v_GS_LOGICAL_DISK.VolumeName0
    FOR XML PATH ('')
),1,1,'') AS [Free Space]
--END Logical Disks for v_R_System
,(CASE WHEN v_GS_PROCESSOR.Name0 LIKE 'AMD%' THEN 'AMD' ELSE SUBSTRING(v_GS_PROCESSOR.Name0,CHARINDEX('@',v_GS_PROCESSOR.Name0) + 2,7) END) 
    + ' (Cores:' + CONVERT(varchar,v_GS_PROCESSOR.NumberOfCores0 * (SELECT COUNT(*) FROM v_GS_PROCESSOR WHERE v_GS_PROCESSOR.ResourceID = v_R_System.ResourceID)) + ')' AS [CPU]
,v_GS_PC_BIOS.SerialNumber0
,v_GS_PC_BIOS.SMBIOSBIOSVersion0
,v_GS_OPERATING_SYSTEM.Caption0 [OS]
--,Operating_System_Name_and0
,v_GS_OPERATING_SYSTEM.BuildNumber0 [OS Build]
,'Virtual: ' + CONVERT(varchar,CEILING(TotalVirtualMemorySize0 / 1024.0)) 
  + 'GB' + CHAR(10) + 'Visible: ' + CONVERT(varchar,CEILING(TotalVisibleMemorySize0 / 1024.0)) 
  + 'GB' + CHAR(10) + 'SWAP: ' + CONVERT(varchar,CEILING(TotalSwapSpaceSize0 / 1024.0)) + 'GB'
   AS [Memory]
,LastBootUpTime0
,v_GS_COMPUTER_SYSTEM.Model0
,v_GS_COMPUTER_SYSTEM.Manufacturer0
,(vSMS_CombinedDeviceResources.LastPolicyRequest + '03:00') [LastPolicyRequest]
,(vSMS_CombinedDeviceResources.LastHardwareScan + '03:00') [LastHardwareScan]
FROM v_R_System
LEFT JOIN v_GS_OPERATING_SYSTEM
 ON v_R_System.ResourceID = v_GS_OPERATING_SYSTEM.ResourceID
LEFT OUTER JOIN v_GS_PROCESSOR
 ON v_R_System.ResourceID = v_GS_PROCESSOR.ResourceID
LEFT OUTER JOIN v_GS_PC_BIOS
 ON v_R_System.ResourceID = v_GS_PC_BIOS.ResourceID
LEFT OUTER JOIN v_GS_COMPUTER_SYSTEM
 ON v_R_System.ResourceID = v_GS_COMPUTER_SYSTEM.ResourceID
LEFT OUTER JOIN vSMS_CombinedDeviceResources
 ON v_R_System.ResourceID = vSMS_CombinedDeviceResources.MachineID
WHERE
v_R_System.AgentEdition0 = '13'
ORDER BY
Netbios_Name0
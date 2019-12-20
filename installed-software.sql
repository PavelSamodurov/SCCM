SELECT
  v_GS_INSTALLED_SOFTWARE.ProductName0 AS [Product Name]
  ,v_GS_INSTALLED_SOFTWARE.ProductVersion0 AS [Version]
  ,v_GS_INSTALLED_SOFTWARE.Publisher0 AS [Publisher]
  ,v_GS_INSTALLED_SOFTWARE.SoftwareCode0 AS [Software Code]
  ,v_GS_INSTALLED_SOFTWARE.UninstallString0 AS [Uninstall String]
  ,v_GS_INSTALLED_SOFTWARE.InstalledLocation0 AS [Installed Location]
  ,v_GS_INSTALLED_SOFTWARE.InstallDate0 AS [Install Date]
  ,v_GS_INSTALLED_SOFTWARE.TimeStamp AS [Time Stamp]
  ,v_R_System.ResourceID
  ,v_R_System.Netbios_Name0 AS [Netbios Name]
  ,v_R_System.Resource_Domain_OR_Workgr0 AS [Domain]
  ,v_R_System.User_Name0 AS [User Name]
  ,v_R_User.displayName0 AS [Full User Name]
  ,v_R_User.department0 AS [Department]
  ,v_GS_OPERATING_SYSTEM.Caption0 AS [OS]
  ,v_GS_OPERATING_SYSTEM.Version0 AS [Build OS]
  ,v_GS_OPERATING_SYSTEM.InstallDate0 AS [Install OS Date]
  ,v_GS_OPERATING_SYSTEM.LastBootUpTime0 AS [Last Bootup]
  ,vSMS_CombinedDeviceResources.LastPolicyRequest
  ,vSMS_CombinedDeviceResources.LastHardwareScan
FROM
  v_R_System
LEFT OUTER JOIN v_R_User
 ON v_R_System.User_Name0 = v_R_User.User_Name0
 AND v_R_System.User_Domain0 = v_R_User.Windows_NT_Domain0
LEFT OUTER JOIN v_GS_OPERATING_SYSTEM
 ON v_R_System.ResourceID = v_GS_OPERATING_SYSTEM.ResourceID
LEFT OUTER JOIN vSMS_CombinedDeviceResources
 ON v_R_System.ResourceID = vSMS_CombinedDeviceResources.MachineID
INNER JOIN v_GS_INSTALLED_SOFTWARE
 ON v_R_System.ResourceID = v_GS_INSTALLED_SOFTWARE.ResourceID
ORDER BY
  v_GS_INSTALLED_SOFTWARE.ProductName0
  ,v_GS_INSTALLED_SOFTWARE.ProductVersion0
  ,v_R_System.Netbios_Name0
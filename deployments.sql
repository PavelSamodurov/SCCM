SELECT DISTINCT
  vAppDTDeploymentResultsPerClient.ResourceID
  ,CASE
    WHEN LEN(vAppDTDeploymentResultsPerClient.ResourceID) = '8' THEN Resource_Domain_OR_Workgr0 + '\' + Netbios_Name0
	ELSE Unique_User_Name0
  END AS [Name]
  ,CASE
    WHEN LEN(vAppDTDeploymentResultsPerClient.ResourceID) = '8' THEN 'Devices'
	ELSE 'Users'
  END AS [Deployment on]
  ,vAppDTDeploymentResultsPerClient.AssignmentID
  ,v_ApplicationAssignment.ApplicationName
--  ,vAppDTDeploymentResultsPerClient.descript as 'Deployment Type Name'
  ,v_ApplicationAssignment.CollectionName as 'Target Collection'
  ,CASE v_ApplicationAssignment.OfferTypeID
     WHEN 0 THEN 'Required'
	 WHEN 2 THEN 'Available'
	END AS 'Purpose'
  ,vAppDTDeploymentResultsPerClient.AppEnforcementState
  ,case when AppEnforcementState = 1000 then 'Success'
	when AppEnforcementState = 1001 then 'Already Compliant'
	when AppEnforcementState = 1002 then 'Simulate Success'
	when AppEnforcementState = 2000 then 'In Progress'
	when AppEnforcementState = 2001 then 'Waiting for Content'
	when AppEnforcementState = 2002 then 'Installing'
	when AppEnforcementState = 2003 then 'Restart to Continue'
	when AppEnforcementState = 2004 then 'Waiting for maintenance window'
	when AppEnforcementState = 2005 then 'Waiting for schedule'
	when AppEnforcementState = 2006 then 'Downloading dependent content'
	when AppEnforcementState = 2007 then 'Installing dependent content'
	when AppEnforcementState = 2008 then 'Restart to complete'
	when AppEnforcementState = 2009 then 'Content downloaded'
	when AppEnforcementState = 2010 then 'Waiting for update'
	when AppEnforcementState = 2011 then 'Waiting for user session reconnect'
	when AppEnforcementState = 2012 then 'Waiting for user logoff'
	when AppEnforcementState = 2013 then 'Waiting for user logon'
	when AppEnforcementState = 2014 then 'Waiting to install'
	when AppEnforcementState = 2015 then 'Waiting retry'
	when AppEnforcementState = 2016 then 'Waiting for presentation mode'
	when AppEnforcementState = 2017 then 'Waiting for Orchestration'
	when AppEnforcementState = 2018 then 'Waiting for network'
	when AppEnforcementState = 2019 then 'Pending App-V Virtual Environment'
	when AppEnforcementState = 2020 then 'Updating App-V Virtual Environment'
	when AppEnforcementState = 3000 then 'Requirements not met'
	when AppEnforcementState = 3001 then 'Host platform not applicable'
	when AppEnforcementState = 4000 then 'Unknown'
	when AppEnforcementState = 5000 then 'Deployment failed'
	when AppEnforcementState = 5001 then 'Evaluation failed'
	when AppEnforcementState = 5002 then 'Deployment failed'
	when AppEnforcementState = 5003 then 'Failed to locate content'
	when AppEnforcementState = 5004 then 'Dependency installation failed'
	when AppEnforcementState = 5005 then 'Failed to download dependent content'
	when AppEnforcementState = 5006 then 'Conflicts with another application deployment'
	when AppEnforcementState = 5007 then 'Waiting retry'
	when AppEnforcementState = 5008 then 'Failed to uninstall superseded deployment type'
	when AppEnforcementState = 5009 then 'Failed to download superseded deployment type'
	when AppEnforcementState = 5010 then 'Failed to updating App-V Virtual Environment'
	WHEN v_ApplicationAssignment.OfferTypeID = 2 THEN 'Available for Install'
	when AppEnforcementState IS NULL then 'Unknown'
	End as 'State Message'
  ,(vAppDTDeploymentResultsPerClient.LastModificationTime + '03:00') AS LastModificationTime
  ,(vAppDTDeploymentResultsPerClient.StartTime + '03:00') AS StartTime
  ,LastComplianceStatus.LastComplianceMessageTime AS [Last Status Time UTC]
  ,(LastComplianceStatus.LastComplianceMessageTime + '03:00') AS [Last Status Time]
FROM vAppDTDeploymentResultsPerClient
LEFT OUTER JOIN v_ApplicationAssignment
 ON vAppDTDeploymentResultsPerClient.AssignmentID = v_ApplicationAssignment.AssignmentID
LEFT OUTER JOIN v_FullCollectionMembership
 ON v_ApplicationAssignment.CollectionID = v_FullCollectionMembership.CollectionID
   AND vAppDTDeploymentResultsPerClient.ResourceID = v_FullCollectionMembership.ResourceID
LEFT OUTER JOIN (
	SELECT 
	  CI_ID
	  ,ResourceID
	  ,MAX(LastComplianceMessageTime) AS LastComplianceMessageTime
	FROM v_CICurrentComplianceStatus
	GROUP BY CI_ID
	,ResourceID
) AS LastComplianceStatus
 ON LastComplianceStatus.CI_ID = vAppDTDeploymentResultsPerClient.CI_ID
  AND vAppDTDeploymentResultsPerClient.ResourceID = LastComplianceStatus.ResourceID
LEFT OUTER JOIN v_R_System
 ON v_R_System.ResourceID = vAppDTDeploymentResultsPerClient.ResourceID
LEFT OUTER JOIN v_R_User
 ON v_R_User.ResourceID = vAppDTDeploymentResultsPerClient.ResourceID
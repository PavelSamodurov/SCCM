SELECT DISTINCT
 v_R_System.ResourceID
  ,v_R_System.Netbios_Name0
  ,v_R_System.Resource_Domain_OR_Workgr0
  ,v_R_System.User_Name0
  ,sqCIStatus.CI_ID AS ConfigurationItemID
  ,v_LocalizedCIProperties.DisplayName AS ConfigurationItemName
  ,DATEADD(hour,3,sqCIStatus.Max_LastComplianceMessageTime) AS LastCompliance
  ,v_CIRules.RuleName
  ,v_CICurrentSettingsComplianceStatusDetail.CurrentValue AS NonCompliantValue
  ,CASE 
    WHEN sqCIStatus.IsApplicable = '0' THEN 'Not Applicable'
    WHEN sqCIStatus.IsDetected = '0' THEN 'Not Detected'
    WHEN sqCIStatus.ComplianceState = '1' THEN 'Compliant'
    WHEN sqCIStatus.ComplianceState = '4' THEN 'Compliant'
    WHEN sqCIStatus.ComplianceState = '2' THEN 'Non Compliant'
    WHEN sqCIStatus.ComplianceState = '5' THEN 'Status 5'
    WHEN sqCIStatus.ComplianceState = '6' THEN 'Status 6'
    ELSE 'Unknown'
  END AS CIState
  ,CASE 
    WHEN sqCIStatus.IsApplicable = '0' THEN 'Not Applicable'
    WHEN sqCIStatus.IsDetected = '0' THEN 'Not Detected'
    WHEN sqCIStatus.ComplianceState = '1' THEN 'Compliant'
    WHEN sqCIStatus.ComplianceState = '4' THEN 'Compliant'
    WHEN sqCIStatus.ComplianceState = '2' THEN v_CICurrentSettingsComplianceStatusDetail.CurrentValue
    WHEN sqCIStatus.ComplianceState = '5' THEN 'Status 5'
    WHEN sqCIStatus.ComplianceState = '6' THEN 'Status 6'
    ELSE 'Unknown'
  END AS CIState_NonCompliantValue
FROM v_R_System
LEFT OUTER JOIN 
    (
    SELECT
        v_CICurrentComplianceStatus.ResourceID
        ,MAX(v_CICurrentComplianceStatus.CI_ID) AS CI_ID
        ,MAX(v_CICurrentComplianceStatus.LastComplianceMessageTime) AS Max_LastComplianceMessageTime
        ,v_CICurrentComplianceStatus.IsApplicable
        ,v_CICurrentComplianceStatus.IsDetected
        ,v_CICurrentComplianceStatus.ComplianceState
    FROM
        v_CICurrentComplianceStatus
    GROUP BY
        v_CICurrentComplianceStatus.ResourceID
        --,v_CICurrentComplianceStatus.CI_ID
        ,v_CICurrentComplianceStatus.IsApplicable
	    ,v_CICurrentComplianceStatus.IsDetected
        ,v_CICurrentComplianceStatus.ComplianceState
    ) sqCIStatus
  ON v_R_System.ResourceID = sqCIStatus.ResourceID
LEFT OUTER JOIN v_CICurrentSettingsComplianceStatusDetail
 ON v_R_System.ResourceID = v_CICurrentSettingsComplianceStatusDetail.ResourceID
JOIN v_CIRules
 ON v_CICurrentSettingsComplianceStatusDetail.CI_ID=v_CIRules.CI_ID
LEFT OUTER JOIN v_LocalizedCIProperties
 ON sqCIStatus.CI_ID = v_LocalizedCIProperties.CI_ID
 AND v_LocalizedCIProperties.LocaleID = '65535'
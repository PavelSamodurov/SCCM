SELECT 
  [EventId]
  ,[CreationTime] AS [Event Time]
  ,CASE
    WHEN CHARINDEX('@', TargetUser) = 0 THEN TargetUser
    ELSE SUBSTRING(TargetUser,0,CHARINDEX('@', TargetUser))
    END AS [Target User]
--   ,[TargetUser] AS [Target User]
  ,CASE 
	WHEN EventID = '4740' THEN LOWER(PrimaryDomain)
	ELSE LOWER(TargetDomain)
  END AS [Target Domain]
  ,CASE 
	WHEN EventID = '4740' THEN String02
	ELSE String01
  END AS [Service Name]
--   ,[CollectionTime]
  ,CASE 
    WHEN EventID = '4740' THEN 'na'
	WHEN EventID = '4768' THEN (
			CASE
			CHARINDEX ('',String07)  WHEN 0 THEN String07
			ELSE RIGHT(String07,CHARINDEX('',REVERSE(String07))-1) 
			END
	)
	--WHEN EventID = '4769' THEN String05
	ELSE (
			CASE
			CHARINDEX ('',String05)  WHEN 0 THEN String05
			ELSE RIGHT(String05,CHARINDEX('',REVERSE(String05))-1) 
			END
		)
  END AS [Client IP Address]
  ,CASE 
	WHEN EventID = '4768' THEN String08
	WHEN EventID = '4769' THEN String06
	ELSE String06
  END AS [Client IP Port]
  ,[TargetSid] AS [Target Sid]
  ,CASE 
	WHEN EventID = '4740' THEN 'na'
	ELSE String02
  END AS [Service Sid]
  ,[String04] AS [Ticket Encryption Type]
  ,[String03] AS [Ticket Options]
  ,[Category]
--   ,[AgentMachine] AS [Agent Machine]
  ,[EventMachine] AS [Event Machine]
--   ,[Source]
--   ,CASE
--   CHARINDEX ('@',TargetUser)  WHEN 0 THEN TargetUser + '@' + TargetDomain
--   ELSE TargetUser
--   END AS [User Principal Name]
--   ,CASE
--   WHEN TargetUser like 'HealthMailbox%' THEN 'HealthMailbox'
--   WHEN CHARINDEX ('$',TargetUser) = '0' THEN 'User'
--   ELSE 'Computer'
--   END AS [Account Type]
--   ,[String05]
--   ,[String06]
--   ,[String07]
--   ,[String08]
FROM AdtServer.dvAll
WHERE EventId IN (@EventId)
  AND TargetUser LIKE '%' + @TargetUser + '%'
  AND String01 LIKE '%' + @ServiceName + '%'
ORDER BY CreationTime DESC
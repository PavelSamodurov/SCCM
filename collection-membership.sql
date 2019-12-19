SELECT
  mem.CollectionID
  ,ResourceID
  ,mem.Name Member
  ,mem.ResourceType
  ,Case
  When mem.ResourceType = 5 Then 'Device'
  When mem.ResourceType = 4 Then 'User'
  Else
  'unknown'
  End As 'Member Type'
  ,Col.[Name] [Collection]
  ,[Domain]
  ,[SiteCode]
FROM v_FullCollectionMembership mem
LEFT JOIN v_Collection Col on mem.CollectionID = Col.CollectionID
--WHERE mem.ResourceType = 5
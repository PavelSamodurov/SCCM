SELECT
  v_FullCollectionMembership.Name AS [v_FullCollectionMembership Name]
  ,v_Collection.CollectionID AS [v_Collection CollectionID]
  ,v_Collection.Name AS [v_Collection Name]
  ,v_Collection.Comment
  ,vSMS_Folders.Name AS [Folder Name]
  ,v_Collection.LastRefreshTime
FROM
  v_Collection
INNER JOIN v_FullCollectionMembership
 ON v_Collection.CollectionID = v_FullCollectionMembership.CollectionID
LEFT OUTER JOIN vFolderMembers
 ON v_Collection.CollectionID = vFolderMembers.InstanceKey
INNER JOIN vSMS_Folders
 ON vFolderMembers.ContainerNodeID = vSMS_Folders.ContainerNodeID
 AND vFolderMembers.ObjectType = 5000
ORDER BY
[Folder Name]
,[v_Collection Name]
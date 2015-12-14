select distinct info1.OBJECT_UNAME project, info2.OBJECT_UNAME msi_user, info2.ABBREVIATION user_id 
from dssmdlnkitem lnk1, dssmdobjinfo info1, dssmdlnkitem lnk2, dssmdobjinfo info2
WHERE lnk1.object_id = info1.object_id 
AND info1.object_type=32 
AND lnk2.LINKITEM_ID = lnk1.LINKITEM_ID
AND lnk2.object_type=34
AND lnk2.object_id = info2.OBJECT_ID
AND info2.SUBTYPE=8704
AND ( info2.CREATE_TIME > (trunc(sysdate) - 2) OR info2.MOD_TIME > (trunc(sysdate) - 2) )
order by 1,2

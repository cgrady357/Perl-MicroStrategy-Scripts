select TO_CHAR((max(lt.LOG_DATE)), 'YYYY-MM-DD HH24:MI:SS') 
from log_user.log_table lt
where lt.HOST = 'ISERVER1'

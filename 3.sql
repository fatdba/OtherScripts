
KUP-11007: conversion error loading table "XCREWATN"."AQTBL_HOTEL_BOOKING"
ORA-22337: the type of accessed object has been evolved
KUP-11009: data for row: SYS_NC00037$ : 0X'8801FE00000106031300020006FE000000258401FE00000025'
---> Data Pump Import (IMPDP) Fails with ORA-2375 ORA-22337 ORA-2372 (Doc ID 2668345.1)

GRANT SELECT ON "SCHEDOPS"."LEG" TO "XCREWABX"
ORA-39083: Object type OBJECT_GRANT failed to create with error:
ORA-01917: user or role 'XCREWABX' does not exist
and 
GRANT SELECT ON "XCREWATN"."CRM_ADD_QUAL" TO "CRMBASEATN"
ORA-39083: Object type OBJECT_GRANT failed to create with error:
ORA-01917: user or role 'CRMBASEATN' does not exist

-->  Ignore those errors after confirming that these missing grants do not impact what you want to achieve with the import.  Alternatively you can avoid the errors by ensuring that the schema's and roles also exist in the target database before the import starts,

ORA-01917: user or role 'XCREWABX' does not exist




ORA-39346: data loss in character set conversion for object COMMENT:"XCREWATN"."INPUT_SIZE"
ORA-39346: data loss in character set conversion for object COMMENT:"XCREWATN"."NO_OBJ_1"
ORA-39346: data loss in character set conversion for object COMMENT:"XCREWATN"."ADD_NO"
ORA-39346: data loss in character set conversion for object COMMENT:"XCREWATN"."CHG_FLIGHT_TIME"
ORA-39346: data loss in character set conversion for object COMMENT:"XCREWATN"."TYPE"
ORA-39346: data loss in character set conversion for object COMMENT:"SCHEDOPS"."RADIO"
--> There is a good metalink note available for this one. Data Loss In Character Set Conversion During Import (IMPDP) with the Same Source and Target Characterset (Doc ID 1958604.1)
As per the note, there are some invalid or corrupt characters are stored in the source database, specially in comments on objects.

As a solution, Ait recommends to apply interim patch 21342624 and run post-install step:
  
KUP-11007: conversion error loading table "XCREWATN"."AQTBL_HOTEL_BOOKING"
ORA-22337: the type of accessed object has been evolved
KUP-11009: data for row: SYS_NC00037$ : 0X'8801FE00000106031300020006FE000000258401FE00000025'


GRANT SELECT ON "SCHEDOPS"."LEG" TO "XCREWABX"
ORA-39083: Object type OBJECT_GRANT failed to create with error:
ORA-01917: user or role 'XCREWABX' does not exist

ORA-01917: user or role 'XCREWABX' does not exist

Failing sql is:
GRANT SELECT ON "XCREWATN"."CRM_ADD_QUAL" TO "CRMBASEATN"
ORA-39083: Object type OBJECT_GRANT failed to create with error:
ORA-01917: user or role 'CRMBASEATN' does not exist


ORA-39346: data loss in character set conversion for object COMMENT:"XCREWATN"."INPUT_SIZE"
ORA-39346: data loss in character set conversion for object COMMENT:"XCREWATN"."NO_OBJ_1"
ORA-39346: data loss in character set conversion for object COMMENT:"XCREWATN"."ADD_NO"
ORA-39346: data loss in character set conversion for object COMMENT:"XCREWATN"."CHG_FLIGHT_TIME"
ORA-39346: data loss in character set conversion for object COMMENT:"XCREWATN"."TYPE"
ORA-39346: data loss in character set conversion for object COMMENT:"SCHEDOPS"."RADIO"

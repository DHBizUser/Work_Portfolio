
.cd "D:/home/RM06analyst/InvDash2.0/UnprocessedData/SAPspool_20250331"
.open :memory:


create  table SP02import (_1,_2,_3,_4,_5,_6,_7,_8,_9,_10);
.import sp02.txt SP02import




.save test01.db

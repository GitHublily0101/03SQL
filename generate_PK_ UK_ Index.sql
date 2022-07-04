-- generate PK or UK or Index
SELECT 
        TableName=O.Name,
        type_desc=idx.type_desc,
    IndexId=ISNULL(KC.[object_id],IDX.index_id),
    IndexName=IDX.Name,
    IndexType=ISNULL(KC.type_desc,'Index'),
    Index_Column_id=IDXC.index_column_id,
    ColumnName=C.Name,
    Sort=CASE INDEXKEY_PROPERTY(IDXC.[object_id],IDXC.index_id,IDXC.index_column_id,'IsDescending')
        WHEN 1 THEN 'DESC' WHEN 0 THEN 'ASC' ELSE '' END,
    Fill_factor=IDX.fill_factor into temp_indexes
FROM sys.indexes IDX
    INNER JOIN sys.index_columns IDXC
        ON IDX.[object_id]=IDXC.[object_id]
            AND IDX.index_id=IDXC.index_id
    LEFT JOIN sys.key_constraints KC
        ON IDX.[object_id]=KC.[parent_object_id]
            AND IDX.index_id=KC.unique_index_id
    INNER JOIN sys.objects O
        ON O.[object_id]=IDX.[object_id]
    INNER JOIN sys.columns C
        ON O.[object_id]=C.[object_id]
            AND O.type='U'
            AND O.is_ms_shipped=0
            AND IDXC.Column_id=C.Column_id
            ORDER BY TableName

SELECT * FROM temp_indexes
DROP table temp_indexes


Declare @sql varchar(4000)
Set @sql='select TableName,type_desc,IndexName,IndexType,fill_factor,'
Select @sql= @sql+'max(case ColumnName when '''+ColumnName+''' then ColumnName+'' ''+sort+'','' else '''' end)+'
From (SELECT distinct ColumnName,sort from temp_indexes where tablename ='hosted_blocking_summary')a
Set @sql= SUBSTRING(@sql,1,LEN(@sql)-1)
PRINT @sql
set @sql=@sql+' from temp_indexes where tablename =''hosted_blocking_summary'' group by TableName,type_desc,IndexName,IndexType,fill_factor'
PRINT @sql
insert into temp_indexes2(TableName,type_desc,IndexName,IndexType,fill_factor,ColumnName)
exec(@sql)


Declare @tablename varchar(400)
Declare @sql varchar(4000)
DECLARE MyCursor CURSOR
FOR SELECT DISTINCT tablename from temp_indexes
OPEN MyCursor
FETCH NEXT FROM  MyCursor INTO @tablename
WHILE @@FETCH_STATUS =0
BEGIN
Set @sql='select TableName,type_desc,IndexName,IndexType,fill_factor,'
Select @sql= @sql+'max(case ColumnName when '''+ColumnName+''' then ColumnName+'' ''+sort+'','' else '''' end)+'
From (SELECT distinct ColumnName,sort from temp_indexes where tablename =@tablename)a
Set @sql= SUBSTRING(@sql,1,LEN(@sql)-1)
PRINT @sql
set @sql=@sql+' from temp_indexes where tablename ='''+@tablename+''' group by TableName,type_desc,IndexName,IndexType,fill_factor'
PRINT @sql
insert into temp_indexes2(TableName,type_desc,IndexName,IndexType,fill_factor,ColumnName)
exec(@sql)
FETCH NEXT FROM  MyCursor INTO @tablename
END
CLOSE MyCursor
DEALLOCATE MyCursor



Declare @sql varchar(4000)
Declare @tablename varchar(400)
set  @tablename='hosted_blocking_summary'
Set @sql='select TableName,type_desc,IndexName,IndexType,fill_factor,'
Select @sql= @sql+'max(case ColumnName when '''+ColumnName+''' then ColumnName+'' ''+sort+'','' else '''' end)+'
From (SELECT distinct ColumnName,sort from temp_indexes where tablename =@tablename)a
Set @sql= SUBSTRING(@sql,1,LEN(@sql)-1)
PRINT @sql
set @sql=@sql+' from temp_indexes where tablename ='''+@tablename+''' group by TableName,type_desc,IndexName,IndexType,fill_factor'
PRINT @sql
insert into temp_indexes2(TableName,type_desc,IndexName,IndexType,fill_factor,ColumnName)
exec(@sql)


DROP table temp_indexes2
SELECT top 0 TableName,type_desc,IndexName,IndexType,fill_factor,ColumnName into temp_indexes2 from temp_indexes

select * from temp_indexes2
delete from temp_indexes2

CREATE TABLE [dbo].[temp_indexes2](
	[TableName] [sysname] NOT NULL,
	[type_desc] [varchar](60) NULL,
	[IndexName] [sysname] NULL,
	[IndexType] [varchar](60) NOT NULL,
	[fill_factor] [tinyint] NOT NULL,
	[ColumnName] [sysname] NULL
) ON [PRIMARY]

GO



select CASE WHEN IndexName LIKE '%pk%' THEN 
'ALTER TABLE '+TableName+' ADD  CONSTRAINT '+IndexName +' PRIMARY KEY '
+type_desc+'('+substring(ColumnName,1,LEN(ColumnName)-1)+')'+CASE WHEN fill_factor=0 THEN '' ELSE ' WITH (FILLFACTOR = '+CAST(fill_factor as varchar)+')' end
WHEN indexname LIKE '%ix%' THEN
'CREATE '+type_desc+' INDEX '+IndexName + ' on '+TableName+' ('+substring(ColumnName,1,LEN(ColumnName)-1)+')'+CASE WHEN fill_factor=0 THEN '' ELSE ' WITH (FILLFACTOR = '+CAST(fill_factor as varchar)+')' end
WHEN indexname LIKE '%un%' THEN
'CREATE UNIQUE'+type_desc+' INDEX '+IndexName + ' on '+TableName+' ('+substring(ColumnName,1,LEN(ColumnName)-1)+')'+CASE WHEN fill_factor=0 THEN '' ELSE ' WITH (FILLFACTOR = '+CAST(fill_factor as varchar)+')' end
end
from temp_indexes2



--select * from sys.key_constraints
select * from sys.check_constraints 
select * from  sys.default_constraints

select 'ALTER TABLE '+OBJECT_NAME(parent_object_id)+' WITH CHECK ADD  CONSTRAINT '+name+' CHECK '+definition from sys.check_constraints 


select 'ALTER TABLE '+OBJECT_NAME(a.parent_object_id)+' ADD  DEFAULT '+definition+' FOR '+b.name from sys.default_constraints a,sys.columns b
 where a.parent_object_id=b.object_id AND a.parent_column_id=b.column_id
 
 
 SELECT * from sys.objects where type ='TR'
 EXEC sp_helptext 'trigger_ua_etl_config'
 
 exec sp_helptrigger ua_etl_config

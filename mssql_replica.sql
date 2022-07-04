
if exists (select * from sys.objects where object_id = object_id(N'dbo.usp_add_linkserver') and objectProperty(object_id, N'IsProcedure') = 1)
    drop procedure dbo.usp_add_linkserver;
	go
create proc usp_add_linkserver @avagroupname nvarchar(128) 
as 

	declare @ServerName varchar(50)
	select top 1  @servername= dh.replica_server_name from  sys.availability_replicas dh 
	join sys.dm_hadr_availability_replica_states dap on dh.group_id= dap.group_id and dh.replica_id=dap.replica_id
    join sys.availability_groups ag on ag.group_id=dap.group_id where role=2 and ag.name=@avagroupname  order by dh.replica_server_name desc

	 while (@@ROWCOUNT=1 and @ServerName is not null)
	 begin

			if exists (select * from sys.servers where name=@ServerName)
				begin
					exec sp_dropserver @ServerName;
				end
			exec sp_addlinkedserver @server=@ServerName, @srvproduct='', @provider='SQLOLEDB',@datasrc=@servername, @provstr='Integrated Security=SSPI;'

			-- Set options
			exec sp_serveroption @ServerName, 'data access', 'true'
			exec sp_serveroption @ServerName, 'rpc', 'true'
			exec sp_serveroption @ServerName, 'rpc out', 'true'
			exec sp_serveroption @ServerName, 'use remote collation', 'true'

		select top 1  @servername= dh.replica_server_name from  sys.availability_replicas dh 
			join sys.dm_hadr_availability_replica_states dap on dh.group_id= dap.group_id and dh.replica_id=dap.replica_id
			join sys.availability_groups ag on ag.group_id=dap.group_id 
			where role=2 and ag.name=@avagroupname  and dh.replica_server_name<@ServerName order by dh.replica_server_name desc
		

	end 

GO



if exists (select * from sys.objects where object_id = object_id(N'dbo.usp_adddb_avagroup') and objectProperty(object_id, N'IsProcedure') = 1)
    drop procedure dbo.usp_adddb_avagroup;
GO
create proc usp_adddb_avagroup (@catalogname nvarchar(128)='productdb',@dbname nvarchar(128), @debug int=0)
as 
     declare @avagroupname  nvarchar(128)='',
			 @backuppath    nvarchar(1024)='',
			 @tsql_recovery nvarchar(1000)='',
		     @tsql_backup   nvarchar(1000)='',
			 @tsql_agupdate nvarchar(1000)='',
			 @tsql_restore  nvarchar(1000)='',
			 @tsql_hadr     nvarchar(255)='',
			 @tsql_get_config nvarchar(512);
begin
set @tsql_get_config=N'
	select top 1  @avagroupname = ag_group_name,@backuppath =backuppath 
			from '+@catalogname+N'.dbo.web_hadr_config  order by update_date desc' 
 EXEC sp_executesql @tsql_get_config,N'@avagroupname nvarchar(128) output,@backuppath  nvarchar(1024) OUTPUT',@avagroupname=@avagroupname output,@backuppath=@backuppath output
 select @backuppath,@avagroupname,@tsql_get_config
	  	-- if is full recovery 
			IF(select recovery_model from tempdb.sys.databases where name=@dbname)<>1
			    begin
				    set @tsql_recovery=N'alter database ['+@dbname+N'] set recovery full with no_wait;'
			    end
	    -- backup database 	   
		    set @tsql_backup=N' 
		     Backup database ['+@dbname+N'] to disk = '''+@backuppath+N'\'+@dbname+N'_initbackup.bak'' with init, noformat ,
		     NAME ='' Initial backup for HADR seeding'', SKIP, NOREWIND, NOUNLOAD,  STATS = 100;
		     Backup log ['+@dbname+N'] to disk = '''+@backuppath+N'\'+@dbname+N'_initbackup.log'' with init, noformat ,
		     NAME ='' Initial backup for HADR seeding'', SKIP, NOREWIND, NOUNLOAD,  STATS = 100;'

		-- move database to availability group
			 set @tsql_agupdate=N' use master;
			 alter availability group  '+@avagroupname+N' add  database '+@dbname+N';'
		 	if @debug>0
				begin 
				   print @tsql_recovery+ @tsql_backup + @tsql_restore+ @tsql_agupdate+ @tsql_hadr
				end
			exec ( @tsql_recovery+ @tsql_backup+@tsql_agupdate); 
       --grant create database permission 
		declare @tsql_permission     nvarchar(255)=''
		set @tsql_permission =N' use master;
		alter availability group '+@avagroupname +N' grant create any database;'
		exec (@tsql_permission)
	    -- restore database to secondary
		-- if there is a same database on the secondary node , will be deleted first
		-- get the note list 
		-- for sql server 2012 and sql server 2014
        declare @version_num int;
		select  @version_num =   @@MICROSOFTVERSION / POWER(2, 24);
       if @version_num <=13
       begin
		   declare @notename nvarchar(128)
		   select  top 1 @notename= dh.replica_server_name from  sys.availability_replicas dh join sys.dm_hadr_availability_replica_states dap
		   on dh.group_id= dap.group_id and dh.replica_id=dap.replica_id join sys.availability_groups ag
		   on ag.group_id=dap.group_id where role=2 and ag.name =@avagroupname  order by dh.replica_server_name desc
	   		 while @@ROWCOUNT=1 and @notename  is not null 
				begin
				declare @tsql_group int
				select  @tsql_group=1  from sys.databases where group_database_id is null and name= @dbname
				if @@ROWCOUNT >0
					begin
					 set @tsql_restore=N'
						 Restore database ['+@dbname+N'] from disk ='''''+@backuppath+N'\'+@dbname+N'_initbackup.bak'''' with norecovery,nounload,replace, stats=5 ;
						 Restore log ['+@dbname+N'] from disk ='''''+@backuppath+N'\'+@dbname+N'_initbackup.log'''' with norecovery,nounload,replace, stats=5 ;'')at  [' +@notename+N']'
					 set @tsql_hadr=N' use master;exec( ''alter database ['+@dbname+'] set hadr availability group = ['+@avagroupname+']'')at  ['+@notename +N']'
					 if @debug>0  print @tsql_restore+@tsql_hadr
					   exec (@tsql_restore +@tsql_hadr)

					 select  top 1 @notename= dh.replica_server_name from  sys.availability_replicas dh join sys.dm_hadr_availability_replica_states dap
					  on dh.group_id= dap.group_id and dh.replica_id=dap.replica_id join sys.availability_groups ag
					  on ag.group_id=dap.group_id where role=2 and ag.name =@avagroupname and dh.replica_server_name<@notename   order by dh.replica_server_name desc
				end
			end
		end
	end
GO

if exists (select * from sys.objects where object_id = object_id(N'dbo.usp_removedb_group') and objectProperty(object_id, N'IsProcedure') = 1)
    drop procedure dbo.usp_removedb_group;
GO

	create proc usp_removedb_group( @dbname nvarchar(128),@debug int=0)
as 
	begin
	 -- move it out of the availability group
		declare @groupname nvarchar(128),
				@tsql_remove nvarchar(512);
				if exists (select *FROM sys.availability_databases_cluster ad join sys.availability_groups ag on ad.group_id=ag.group_id
					where ad.database_name=@dbname)
					begin
						select @groupname =name FROM sys.availability_databases_cluster ad join sys.availability_groups ag on ad.group_id=ag.group_id
							where ad.database_name=@dbname
						set @tsql_remove=N' use master; ALTER AVAILABILITY GROUP['+@groupname +'] REMOVE DATABASE ['+@dbname+'];  '
						exec (@tsql_remove);
					  end
		waitfor delay '00:00:05';
	 ---restore or drop database from secondary nodes
	   declare @notename nvarchar(128),
	           @tsql_dropdb nvarchar(512);
	   select  top 1 @notename= dh.replica_server_name from  sys.availability_replicas dh join sys.dm_hadr_availability_replica_states dap
	   on dh.group_id= dap.group_id and dh.replica_id=dap.replica_id join sys.availability_groups ag
	   on ag.group_id=dap.group_id where role=2 and ag.name =@groupname  order by dh.replica_server_name desc
	   	 while @@ROWCOUNT=1 and @notename  is not null 
	        begin
				set @tsql_dropdb=N'exec( '' Drop  database '+@dbname+''' )at  [' +@notename+N']';
			if @debug>0  print @tsql_dropdb
		    exec (@tsql_dropdb);
				   
		  select  top 1 @notename= dh.replica_server_name from  sys.availability_replicas dh join sys.dm_hadr_availability_replica_states dap
	         on dh.group_id= dap.group_id and dh.replica_id=dap.replica_id join sys.availability_groups ag
	         on ag.group_id=dap.group_id where role=2 and ag.name =@groupname and dh.replica_server_name<@notename   order by dh.replica_server_name desc
			end

	 end
 go
if exists (select * from sys.objects where object_id = object_id(N'dbo.usp_hadr_init') and objectProperty(object_id, N'IsProcedure') = 1)
    drop procedure dbo.usp_hadr_init;
GO
	create proc usp_hadr_init(@catalogname nvarchar(128)='wslogdb70',@avagroupname nvarchar(128)='test11',@backuppath nvarchar(2000),   @debug int =0)
	as
	   declare @tsql_create_config nvarchar(1024);
begin
     
   if @backuppath is null
   begin
        print'backuppath can not be null  please input the shared path for the database backup'
		return ;
	end

 	if isnull(SERVERPROPERTY('ishadrenabled'),-1433)<>1  -- enabled
		begin
			 print 'please enable hadr first';
			 return;
		end
	---- catalogdb is exists
	if not exists (select * from tempdb.sys.databases where name=@catalogname)
		begin
			print 'no database named'+@catalogname;
			return;
		end
	-- init link server 
	 exec dbo.usp_add_linkserver @avagroupname;
	 
	if not exists (SELECT * FROM tempdb.sys.availability_groups where name=@avagroupname)
		begin
			print 'no availability group named'+@avagroupname
			return
		end
	if not exists (select  dh.replica_server_name from  sys.availability_replicas dh join sys.dm_hadr_availability_replica_states dap
	  on dh.group_id= dap.group_id and dh.replica_id=dap.replica_id join sys.availability_groups ag
	  on ag.group_id=dap.group_id where role=2   )

		begin
			print 'please make sure SQL cluster mast have one secondary node'
			return
		end
	--- create config table for the repla 
	set @tsql_create_config=N'use '+@catalogname+N';
	if not  exists (select * from sys.objects where object_id = object_id(N''dbo.web_hadr_config'') and objectProperty(object_id, N''isusertable'') = 1)
		begin
			create table dbo.web_hadr_config (
			[web_hadr_config_id]  int identity (1, 1),
			[ag_group_name]       nvarchar(128),
			[backuppath]          nvarchar(1024),
			[update_date]    smalldatetime default getdate(),
    
		);
	insert web_hadr_config(ag_group_name,backuppath) select '''+@avagroupname +N''' , '''+@backuppath+N'''; end'
	 if @debug>0 print @tsql_create_config 
	exec (@tsql_create_config);
	declare @notename nvarchar(128)
	select  top 1 @notename= dh.replica_server_name from  sys.availability_replicas dh join sys.dm_hadr_availability_replica_states dap
	  on dh.group_id= dap.group_id and dh.replica_id=dap.replica_id join sys.availability_groups ag
	  on ag.group_id=dap.group_id where role=2 and ag.name =@avagroupname  order by dh.replica_server_name desc
	 while @@ROWCOUNT=1 and @notename  is not null 
	    begin
		    declare  @dbname nvarchar(128)='';
			select top 1 @dbname =name from tempdb.sys.databases where charindex ( @catalogname,name)>0 and replica_id is null order by name desc
			while @@ROWCOUNT=1 and @dbname is not null
			    begin
				     exec usp_adddb_avagroup @catalogname,@dbname,@debug;
				    select top 1 @dbname =name from tempdb.sys.databases where charindex ( @catalogname,name)>0 and replica_id is null and name<@dbname order by name desc
				end

		    select  top 1 @notename= dh.replica_server_name from  sys.availability_replicas dh join sys.dm_hadr_availability_replica_states dap
	  on dh.group_id= dap.group_id and dh.replica_id=dap.replica_id join sys.availability_groups ag
	  on ag.group_id=dap.group_id where role=2 and ag.name =@avagroupname and dh.replica_server_name<@notename   order by dh.replica_server_name desc
		end

end

GO


 if exists (select * from sys.objects where object_id = object_id(N'dbo.usp_delete_partitions') and objectProperty(object_id, N'IsProcedure') = 1)
    drop procedure dbo.usp_delete_partitions;
GO

 create procedure [dbo].[usp_delete_partitions] @debug bit = 0 as
 begin
     set nocount on;
     declare @dbName       sysname,
             @done         int,
             @partition_id int,
             @count        int,
             @str          nvarchar(4000),
             @sql          nvarchar(4000),
             @version      sql_variant;
 
     if @debug > 0 print '==> Enter usp_delete_partitions()';
     select @partition_id=min(web_partition_id) from dbo.web_partitions where deleted = 1;
 
     -- make sure to drop table if it exists
     set @done = 0
     set @str = '('
     while @partition_id is not null
     begin
       select @dbname = [db_name] from dbo.web_partitions  where web_partition_id = @partition_id;
       select @count = count(*) from sys.databases where name= @dbName;
       if @count > 0
       begin
         if @debug > 0 print 'Dropping partition : ' + @dbName;
         --- remove from availability group if needed
		 exec dbo.usp_removedb_group @dbname;
         -- kill all active users
         set @SQL = N'ALTER DATABASE ' + @dbName + N' SET SINGLE_USER WITH ROLLBACK IMMEDIATE';
         exec dbo.usp_run_sql @sql, N'usp_delete_partitions', @debug;
 
         -- drop it
         set @SQL = N'drop database ' + @dbName
         exec dbo.usp_run_sql @sql, N'usp_delete_partitions', @debug;
         exec dbo.usp_event_log N'audit', @SQL;
 
         set @done = @done + 1
         set @str = @str + cast(@partition_id as varchar) + ','
       end
 
       select @partition_id=min(web_partition_id) 
         from dbo.web_partitions where deleted = 1 and web_partition_id > @partition_id;
     end -- while
     set @str = @str + N'0)'
 
     -- update partitions
     set @SQL= N'update dbo.web_partitions set last_updated = getDate() where deleted=1 and web_partition_id in ' + @str;
     if @debug = 1
         print @sql;
     exec dbo.usp_run_sql @sql, N'usp_delete_partitions', @debug;
     return 0;
 end -- usp_delete_partitions

 GO


 if exists (select * from sys.objects where object_id = object_id(N'dbo.usp_new_partition') and objectProperty(object_id, N'IsProcedure') = 1)
    drop procedure dbo.usp_new_partition;
GO

 create procedure dbo.usp_new_partition
     @new_partition_name        sysname,    -- system length limit
     @current_partition_id      int,
     @db_root_location          nvarchar(1024) = null,
     @partition_data_location   nvarchar(1024) = null,
     @partition_data_init_size  int = null,
     @partition_data_growth     int = null,
     @partition_log_location    nvarchar(1024) = null,
     @partition_log_init_size   int = null,
     @partition_log_growth      int = null,
     @recovery_simple           bit = 1,
     @debug                     tinyint = 0
 as 
     begin
         set NOCOUNT on
 
         declare @sql nvarchar(4000),
                 @parmdef nvarchar(200),
                 @resultname sysname,
                 @retval int,
                 @identity_base bigint,
                 @identity_top bigint,
                 @errnum int,
                 @errmsg nvarchar(4000),
                 @partitionmax smallint,
                 @level tinyint,
                 @status int;
 
         if @debug > 0 print N'==>Enter usp_new_partition() ';
      
         select @level = 0,  -- init & validation
                @ErrMsg = N'Validation error';
      
         if dbo.udf_dbcreate_permission() = 0
         begin
             exec dbo.usp_event_log N'error', N'The database user does not have permission to create databases';
             raiserror(N'usp_new_partition(): %s', 16, 1, N'The database user does not have permission to create databases.');
             return -1;
         end
 
         select top 1 @partitionMax = partition_db_max from dbo.web_db_config order by created_date desc;
         if @@rowcount < 1 or @partitionMax is null
             begin
                 set @partitionMax = 70
             end
 
         -- Make sure at most 250 partitions are supported
         select @RetVal = count(*) from dbo.web_partitions where deleted = 0 and offline = 0
         if (@RetVal >= @partitionMax)
             begin
                 select @ErrNum = 1, @ErrMsg = N'usp_new_partition() Error Maximum partition number reached. ';
                 exec dbo.usp_event_log N'error', @ErrMsg;
                 goto Error_Handler;
             end
 
         -- create the new database now
         select @level = 2,
                @ErrMsg = N'Partition creation error';
         exec @status = dbo.usp_setup_partition @new_partition_name, @Current_Partition_id, @db_root_location,
                                      @partition_data_location, @partition_data_init_size, @partition_data_growth,
                                      @partition_log_location, @partition_log_init_size, @partition_log_growth, @recovery_simple, 
                                      @Identity_Base output, @Identity_Top output, @debug;
		 if @status < 0
             begin
                 goto Error_Handler;
             end
          
		  --ADD DB to ALWYAON
		exec dbo.usp_hadr_init @catalogname=@NEW_PARTITION_NAME, @avagroupname ='AG_Test',@backuppath='\\ACTIVEDIRECTORY\Temp'

         -- handle product to turn off etl buffersize
         select @level = 6,  -- last state completed;  create db_version table in partition;
                @ErrMsg = N'Partition table setup error';
         set @ParmDef = @NEW_PARTITION_NAME + N', ' + cast(@Identity_Top as varchar) + N', ' + cast(@Identity_Base as varchar);
         exec @status = dbo.usp_product_feature_run_task N'db_partition_table_create', @ParmDef, @debug;
         if @status < 0
             begin
                 goto Error_Handler;
             end;
        
         ----------------------------------------------
         -- Update the Catalog Partitions information
         ----------------------------------------------
         select @level = 7,  -- last state completed;  update catelog table setting
                @ErrMsg = N'Partition database update catalog db setting error';
                
         declare @etl_db_config int;
         select @etl_db_config = dbo.udf_etl_db_get_versionid();
 
         begin try
             if (@debug = 1)
                 begin
					 print N'usp_new_partition ==> insert records to partitions ';
					 end
             insert into dbo.web_partitions (web_PARTITION_ID, [DB_NAME], web_etl_db_config_id, web_detail_max, wtg_detail_max)
                   values (@CURRENT_PARTITION_ID, @NEW_PARTITION_NAME, @etl_db_config, (@Identity_Base-1), (@Identity_Base-1));
         end try
         begin catch                       
             set @ErrMsg =   CAST(error_line() as varchar) + ': ' + ERROR_MESSAGE();
             exec dbo.usp_event_log N'error', @ErrMsg;
             goto Error_Handler;
         end catch
 
         if @debug > 0
             begin
                 print N'==>Exit  usp_new_partition()';
             end
         return 0;
 
       -----------------------------------
       -- Error Logging and Return Value
       -----------------------------------
     Error_Handler:
         set @ErrMsg = N'usp_new_partition() : ' + isNULL(@ErrMsg, N'create database error ');
         exec dbo.usp_event_log N'error', @ErrMsg, @debug;
         
         -- may need to do some cleanup
         if exists (select 1 from sys.databases where name= @new_partition_name) and @debug = 0 and @level >= 2
             begin
                 set @SQL = N'drop database ' + @NEW_PARTITION_NAME;
                 exec sp_executesql @SQL;   
             end
 
         RAISERROR('%s', 16, 1, @ErrMsg);
         return -1;
     end  -- usp_new_partition
 
 GO

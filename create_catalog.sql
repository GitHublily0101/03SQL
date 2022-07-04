if not exists (select * from sys.databases where name='%CATALOGDB%')
	begin
	     declare @modeldev_size int;
         declare @tsql nvarchar(1000)
		 select @modeldev_size = size/128.0 from sys.master_files where name = N'modeldev';
		 if @modeldev_size<10 set @modeldev_size=10
		 
		set @tsql=N'CREATE DATABASE %CATALOGDB% on primary ( NAME = ''%CATALOGDB%'', FILENAME = ''%FILEPATH%%CATALOGDB%.mdf'', SIZE ='+ cast(@modeldev_size as nvarchar)+N' MB) LOG ON (NAME = ''%CATALOGDB%_log'', FILENAME = ''%FILEPATH%%CATALOGDB%_log.ldf'')'
        exec(@tsql)
		declare @engineEdition int;
		select @engineEdition = cast(serverProperty(N'EngineEdition') as int);
		if @engineEdition=4 
			begin
				alter database %CATALOGDB% set trustworthy on;
				alter database %CATALOGDB% set enable_broker with rollback immediate; 
			end
	end 
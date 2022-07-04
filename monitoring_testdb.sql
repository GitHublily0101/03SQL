CREATE database Monitor_temp
go


use Monitor_temp
GO 
CREATE table Monitortempspace(fileid int,mdate datetime, muserd_space int)
go

CREATE table MonitorSQL(Spid int, dbname varchar(100),user_nm varchar(100),Status varchar(100),Wait varchar(100), Individual_Query varchar(4000),Parent_Query varchar(4000),
Program varchar(1000), nt_domain varchar(500), start_time datetime,currenttime datetime)
go

CREATE procedure P_Monitortempspace as
begin
insert into Monitortempspace
select fileid,GETDATE(),size from sys.sysfiles

insert INTO MonitorSQL
SELECT    session_Id, DB_NAME(sp.dbid),nt_username, er.status, 
 wait_type,  substring(SUBSTRING(qt.text, er.statement_start_offset / 2, (CASE WHEN er.statement_end_offset = - 1 THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) 
                      * 2 ELSE er.statement_end_offset END - er.statement_start_offset) / 2),1,3900),
substring(qt.text,1,3900),  program_name,  nt_domain, start_time,GETDATE()
FROM    
     sys.dm_exec_requests er INNER JOIN  sys.sysprocesses sp ON er.session_id = sp.spid 
     CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) AS qt
WHERE     session_Id > 50 /* Ignore system spids.*/ AND session_Id NOT IN (@@SPID)

end
go
USE msdb;
GO
 
EXEC dbo.sp_add_job
      @job_name = N'Monitor_temp_space';
GO
 
EXEC sp_add_jobstep
      @job_name = N'Monitor_temp_space',
      @step_name = N'execute P_Monitortempspace script', 
      @subsystem = N'TSQL',
      @command = N'exec P_Monitortempspace',
@database_name=N'Monitor_temp';
GO   
 
EXEC sp_add_jobSchedule
      @name = N'ScheduleBlockingCheck',
      @job_name = N'Monitor_temp_space',
      @freq_type = 4, -- daily
      @freq_interval = 1,
      @freq_subday_type = 0x4,
      @freq_subday_interval = 10
 
EXEC sp_add_jobserver @job_name = N'Monitor_temp_space', @server_name = N'(local)'

go


use Monitor_temp
go
select * from Monitortempspace
select * FROM MonitorSQL
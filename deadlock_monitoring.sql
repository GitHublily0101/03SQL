CREATE DATABASE [MonitorBlocking]
GO
 
USE [MonitorBlocking]
GO
 
CREATE TABLE Blocking_sysprocesses(
      [spid] smallint,
      [kpid] smallint,
      [blocked] smallint,
      [waitType] binary(2),
      [waitTime] bigInt,
      [lastWaitType] nchar(32),
      [waitResource] nchar(256),
      [dbID] smallint,
      [uid] smallint,
      [cpu] int,
      [physical_IO] int,
      [memusage] int,
      [login_Time] datetime,
      [last_Batch] datetime,
      [open_Tran] smallint,
      [status] nchar(30),
      [sid] binary(86),
      [hostName] nchar(128),
      [program_Name] nchar(128),
      [hostProcess] nchar(10),
      [cmd] nchar(16),
      [nt_Domain] nchar(128),
      [nt_UserName] nchar(128),
      [net_Library] nchar(12),
      [loginName] nchar(128),
      [context_Info] binary(128),
      [sqlHandle] binary(20),
      [CapturedTimeStamp] datetime
)
GO
CREATE TABLE [dbo].[Blocking_SqlText](
      [spid] [smallint],
      [sql_text] [nvarchar](2000),
      [Capture_Timestamp] [datetime]
)
GO
 
CREATE PROCEDURE [dbo].[checkBlocking]
AS
BEGIN
 
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
 
declare @Duration   int -- in milliseconds, 1000 = 1 sec
declare @now            datetime
declare @Processes  int
 
select  @Duration = 100  -- in milliseconds, 1000 = 1 sec
select  @Processes = 0
 
select @now = getdate()
 
CREATE TABLE #Blocks_rg(
      [spid] smallint,
      [kpid] smallint,
      [blocked] smallint,
      [waitType] binary(2),
      [waitTime] bigInt,
      [lastWaitType] nchar(32),
      [waitResource] nchar(256),
      [dbID] smallint,
      [uid] smallint,
      [cpu] int,
      [physical_IO] int,
      [memusage] int,
      [login_Time] datetime,
      [last_Batch] datetime,
      [open_Tran] smallint,
      [status] nchar(30),
      [sid] binary(86),
      [hostName] nchar(128),
      [program_Name] nchar(128),
      [hostProcess] nchar(10),
      [cmd] nchar(16),
      [nt_Domain] nchar(128),
      [nt_UserName] nchar(128),
      [net_Library] nchar(12),
      [loginName] nchar(128),
      [context_Info] binary(128),
      [sqlHandle] binary(20),
      [CapturedTimeStamp] datetime
)    
     
INSERT INTO #Blocks_rg 
SELECT
      [spid],
      [kpid],
      [blocked],
      [waitType],
      [waitTime],
      [lastWaitType],
      [waitResource],
      [dbID],
      [uid],
      [cpu],
      [physical_IO],
      [memusage],
      [login_Time],
      [last_Batch],
      [open_Tran],
      [status],
      [sid],
      [hostName],
      [program_name],
      [hostProcess],
      [cmd],
      [nt_Domain],
      [nt_UserName],
      [net_Library],
      [loginame],
      [context_Info],
      [sql_Handle]--,
     -- @now as [Capture_Timestamp]
FROM master..sysprocesses where blocked <> 0
AND waitTime > @Duration     
     
SET @Processes = @@rowcount
 
INSERT into #Blocks_rg
SELECT
 
      src.[spid],
      src.[kpid],
      src.[blocked],
      src.[waitType],
      src.[waitTime],
      src.[lastWaitType],
      src.[waitResource],
      src.[dbID],
      src.[uid],
      src.[cpu],
      src.[physical_IO],
      src.[memusage],
      src.[login_Time],
      src.[last_Batch],
      src.[open_Tran],
      src.[status],
      src.[sid],
      src.[hostName],
      src.[program_name],
      src.[hostProcess],
      src.[cmd],
      src.[nt_Domain],
      src.[nt_UserName],
      src.[net_Library],
      src.[loginame],
      src.[context_Info],
      src.[sql_Handle]
      ,@now as [Capture_Timestamp]
FROM  master..sysprocesses src inner join #Blocks_rg trgt
       on trgt.blocked = src.[spid]
 
if @Processes > 0
BEGIN
      INSERT [dbo].[Blocking_sysprocesses]
      SELECT * from #Blocks_rg
     
DECLARE @SQL_Handle binary(20), @SPID smallInt;
DECLARE cur_handle CURSOR FOR SELECT sqlHandle, spid FROM #Blocks_rg;
OPEN cur_Handle
FETCH NEXT FROM cur_handle INTO @SQL_Handle, @SPID
WHILE (@@FETCH_STATUS = 0)
BEGIN
 
INSERT [dbo].[Blocking_SqlText]
SELECT      @SPID, CONVERT(nvarchar(4000), [text]) ,@now as [Capture_Timestamp] from ::fn_get_sql(@SQL_Handle)
 
FETCH NEXT FROM cur_handle INTO @SQL_Handle, @SPID
END
CLOSE cur_Handle
DEALLOCATE cur_Handle
 
END
 
DROP table #Blocks_rg
 
END
 
GO
 
 
 
 
USE msdb;
GO
 
EXEC dbo.sp_add_job
      @job_name = N'MonitorBlocking';
GO
 
EXEC sp_add_jobstep
      @job_name = N'MonitorBlocking',
      @step_name = N'execute blocking script', 
      @subsystem = N'TSQL',
      @command = N'exec checkBlocking',
@database_name=N'MonitorBlocking';
GO   
 
EXEC sp_add_jobSchedule
      @name = N'ScheduleBlockingCheck',
      @job_name = N'MonitorBlocking',
      @freq_type = 4, -- daily
      @freq_interval = 10,
      @freq_subday_type = 4,
      @freq_subday_interval = 10
 
EXEC sp_add_jobserver @job_name = N'MonitorBlocking', @server_name = N'(local)'
 
当Blocking发生一段时间后，我们可以查询下面的两个表格，以得知当时问题发生时的blocking信息:
 
 
use MonitorBlocking
GO   
SELECT * from Blocking_sqlText
SELECT * FROM Blocking_sysprocesses



declare 
@scheduleid BINARY(16),@start_time nvarchar(6),@end_time nvarchar(6);
BEGIN SELECT top 1 @scheduleid=b.schedule_id 
FROM msdb..sysjobs a, msdb..sysjobschedules b 
where a.job_id=b.job_id AND a.name like '%ETL_Job%' 
SELECT top 1 @end_time=B.next_run_time 
FROM msdb..sysjobs a, msdb..sysjobschedules b 
where a.job_id=b.job_id AND a.name like '%IBT_DRIVER%' 
set @start_time=cast(cast(@end_time AS int)+500 as nvarchar(6)) 
set @end_time=cast(cast(@end_time AS int)-5000 as nvarchar(6)) 
EXEC msdb.dbo.sp_update_schedule @schedule_id=@scheduleid, @active_start_time=@start_time,@active_end_time=@end_time
end
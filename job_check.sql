SELECT
    [job].[name] 
   ,[steps].[command]
   , CASE WHEN [jobh].[run_date] IS NULL
               OR [jobh].[run_time] IS NULL THEN NULL
          ELSE CAST ( CAST ([jobh].[run_date] AS CHAR ( 8 )) + ' '
               + STUFF(STUFF( RIGHT ( '000000'
                                   + CAST ([jobh].[run_time] AS VARCHAR ( 6 )), 6 ),
                             3 , 0 , ':' ), 6 , 0 , ':' ) AS DATETIME)
     END AS 'last_run_date'
   , CASE [jobh].[run_status]
      WHEN 0 THEN 'Failed'
      WHEN 1 THEN 'Succeed'
      WHEN 2 THEN 'retry'
      WHEN 3 THEN 'Canceled'
      WHEN 4 THEN 'Running'
	  WHEN 5 THEN 'Unknow'
     END AS 'last_run_status'
   ,STUFF(STUFF( RIGHT ( '000000' + CAST ([jobh].[run_duration] AS VARCHAR ( 6 )), 6 ),
                 3 , 0 , ':' ), 6 , 0 , ':' ) AS 'last_run_duration'
   ,[jobh].[message] AS 'last_run_message'
   , CASE [jsch].[NextRunDate]
      WHEN 0 THEN NULL
       ELSE CAST ( CAST ([jsch].[NextRunDate] AS CHAR ( 8 )) + ' '
            + STUFF(STUFF( RIGHT ( '000000'
                                + CAST ([jsch].[NextRunTime] AS VARCHAR ( 6 )),
                                6 ), 3 , 0 , ':' ), 6 , 0 , ':' ) AS DATETIME)
     END AS 'next_run_time'
FROM [msdb].[dbo].[sysjobs] AS [job]
LEFT JOIN (
             SELECT
                [job_id]
               , MIN ([next_run_date]) AS [NextRunDate]
               , MIN ([next_run_time]) AS [NextRunTime]
             FROM [msdb].[dbo].[sysjobschedules]
             GROUP BY [job_id]
          ) AS [jsch]
         ON [job].[job_id] = [jsch].[job_id]
LEFT JOIN (
             SELECT
                [job_id]
               ,[run_date]
               ,[run_time]
               ,[run_status]
               ,[run_duration]
               ,[message]
               ,ROW_NUMBER() OVER ( PARTITION BY [job_id] ORDER BY [run_date] DESC , [run_time] DESC ) AS RowNumber
             FROM [msdb].[dbo].[sysjobhistory]
             WHERE [step_id] = 0
          ) AS [jobh]
     ON [job].[job_id] = [jobh].[job_id]
        AND [jobh].[RowNumber] = 1
LEFT JOIN msdb..sysjobsteps steps
	ON [job].[job_id] = [steps].[job_id]
WHERE [job].[name] like '%websense%'
ORDER BY [job].[name]
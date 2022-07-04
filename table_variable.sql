 declare @table table (id int identity(1, 1) primary key,category_id int, cat_name nvarchar(100), child_name nvarchar(100), hits int)
 insert @table
 exec @status = dbo.usp_run_sql @SQL, 'usp_amt_get_category_count()', @debug;
  begin
    select d.category_id, d.cat_name,d.child_name, convert(char(10), m.date_time,120), 0, m.hits from
    amt_trend_category_weekly m, @table d, v_severity_categories
    where
    m.date_time between convert(char(10), GETDATE()- @dateTime, 120) and convert(char(10), GETDATE(), 120)
    AND
    d.category_id = m.category_id
    and d.category_id = v_severity_categories.category_id
    order by d.cat_name,d.child_name, m.date_time
 end
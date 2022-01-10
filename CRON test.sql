SELECT * FROM [cron].[GetNextSchedule]('* * * * *', 5)                  --Each minute
SELECT * FROM [cron].[GetNextSchedule]('59 23 31 12 5', 1)              --One minute  before the end of year if the last day of the year is Friday
SELECT * FROM [cron].[GetNextSchedule]('45 17 7 6 * ', 10)               --Every  year, on June 7th at 17:45 
SELECT * FROM [cron].[GetNextSchedule]('*/15 */6 1,15,31 * 1-5', 20)     --At 00:00, 00:15, 00:30, 00:45, 06:00, 06:15, 06:30, 06:45, 12:00, 12:15, 12:30, 12:45, 18:00, 18:15, 18:30, 18:45, on 1st, 15th or  31st of each  month, but not on weekends
SELECT * FROM [cron].[GetNextSchedule]('0 12 * * 1-5', 24)               --At midday on weekdays

SELECT [cron].[GetPreviousSchedule]('* * * * *')              --Each minute
SELECT [cron].[GetPreviousSchedule]('59 23 31 12 5')          --One minute  before the end of year if the last day of the year is Friday
SELECT [cron].[GetPreviousSchedule]('45 17 7 6 * ')           --Every  year, on June 7th at 17:45 
SELECT [cron].[GetPreviousSchedule]('*/15 */6 1,15,31 * 1-5') --At 00:00, 00:15, 00:30, 00:45, 06:00, 06:15, 06:30, 06:45, 12:00, 12:15, 12:30, 12:45, 18:00, 18:15, 18:30, 18:45, on 1st, 15th or  31st of each  month, but not on weekends
SELECT [cron].[GetPreviousSchedule]('0 12 * * 1-5')           --At midday on weekdays

--*******************************************************************************************
--*******************************************************************************************
--******  Internal functions. Used as encapslulation of functionality
--*******************************************************************************************
--*******************************************************************************************



-- Returns a list of numbers between Min and Max. 
-- If EveryN is other than 1, only Every N number is returned.
-- Function returns incusive numbers
SELECT * FROM [cron].[internal_GetNumbers](1, 5, 1)
SELECT * FROM [cron].[internal_GetNumbers](0, 23, 3)
SELECT * FROM [cron].[internal_GetNumbers](3, 35, 10)


-- Parses a cron partition expression. The format of this expression is: [number or range]/partition
-- Returns the number or range cron expression and the partition number (EveryN value)
SELECT * FROM [cron].[internal_ParseEveryNExpression]('0/1')
SELECT * FROM [cron].[internal_ParseEveryNExpression]('0-23/5')
SELECT * FROM [cron].[internal_ParseEveryNExpression]('5-1')         --separator missing
--SELECT * FROM [cron].[internal_ParseEveryNExpression]('error/test')  --Results in error

-- Parses a cron range, which is in the format 'Min-Max'
-- Returns from (min) and to (max) numbers
SELECT * FROM [cron].[internal_ParseRangeExpression]('2-5')
SELECT * FROM [cron].[internal_ParseRangeExpression]('0-23')
SELECT * FROM [cron].[internal_ParseRangeExpression]('5-1')       --Ordering is wrong
SELECT * FROM [cron].[internal_ParseRangeExpression]('25')        --No actual range
--SELECT * FROM [cron].[internal_ParseRangeExpression]('an-error')  --Results in error

-- Parses an entire field part complete with ranges and partitions where applicable
-- Uses [internal_ParseRangeExpression] and [internal_ParseEveryNExpression] for parsing
-- Returns a list of all numbers matching the Range/EveryN expression part.
SELECT * FROM [cron].[internal_ParseFieldPart]('0', 0, 10)            --Zero 
SELECT * FROM [cron].[internal_ParseFieldPart]('*', 0, 10)            --All numbers between 0 and 10
SELECT * FROM [cron].[internal_ParseFieldPart]('0-20/5', 0, 20)       --Every 5 numbers from 0 to 20
SELECT * FROM [cron].[internal_ParseFieldPart]('* / 5', 0, 20)        --Every 5 numbers from 0 to 20 (extra spaces added due to T-SQL comments)
SELECT * FROM [cron].[internal_ParseFieldPart]('5-1', 0, 100)         --wrong order, no result
--SELECT * FROM [cron].[internal_ParseFieldPart]('error/test', 0, 100)  --Results in error

-- Calls the [cron].[internal_ParseFieldPart] once for every (comma separated) field part
-- in the cron expression. Is the main parsing function per field.
--Returns a unique number list based on the entire field.
SELECT * FROM [cron].[internal_ParseField]('0', 0, 10)            --Zero 
SELECT * FROM [cron].[internal_ParseField]('0,5,7', 0, 10)        --Zero, 5 and 7
SELECT * FROM [cron].[internal_ParseField]('1-4,3,8', 0, 10)      --1-4, 8 and 3 (duplicate) 
SELECT * FROM [cron].[internal_ParseField]('*', 0, 10)            --All numbers between 0 and 10
SELECT * FROM [cron].[internal_ParseField]('0-20/5', 0, 20)       --Every 5 numbers from 0 to 20
SELECT * FROM [cron].[internal_ParseField]('0-20/5,18', 0, 20)    --Every 5 numbers from 0 to 20 and also 18
SELECT * FROM [cron].[internal_ParseField]('5-1', 0, 100)         --wrong order, no result
--SELECT * FROM [cron].[internal_ParseField]('5,error/test', 0, 100)  --Results in error



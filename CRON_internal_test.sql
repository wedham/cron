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



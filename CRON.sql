--Copyright (c) 2022 Mikael Wedham 

--Permission is hereby granted, free of charge, to any person obtaining a copy
--of this software and associated documentation files (the "Software"), to deal
--in the Software without restriction, including without limitation the rights
--to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--copies of the Software, and to permit persons to whom the Software is
--furnished to do so, subject to the following conditions:
--
--The above copyright notice and this permission notice shall be included in all
--copies or substantial portions of the Software.
--
--THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--SOFTWARE.


IF NOT EXISTS ( SELECT * FROM sys.schemas WHERE name = N'cron' )
 EXEC('CREATE SCHEMA [cron] AUTHORIZATION [dbo]');
GO

/*******************************************************************************
--Copyright (c) 2022 Mikael Wedham (MIT License)
   -----------------------------------------
   [cron].[internal_GetNumbers]
   -----------------------------------------
   Base functionality of the interval parser
   Returns a list of numbers between the parameters Min and Max. 
   EveryN parameter selects Every N rows only.

   USAGE:
   --Get every number between 1 and 5
   SELECT * FROM [cron].[internal_GetNumbers](1, 5, 1)
   --Get every third number between 1 and 24
   SELECT * FROM [cron].[internal_GetNumbers](0, 23, 3)
   --Get every 10th number between 3 and 35
   SELECT * FROM [cron].[internal_GetNumbers](3, 35, 10)

Date		Name				Description
----------	-------------		-----------------------------------------------
2022-01-10	Mikael Wedham		+Created v1
*******************************************************************************/
CREATE OR ALTER FUNCTION [cron].[internal_GetNumbers]
(@Min int, @Max int, @EveryN int) 
RETURNS @result TABLE (number int)
AS
BEGIN
	--Assume NULL means every value
    SET @EveryN = ISNULL(@EveryN, 1)
	--Ranges must be entered left-to-right
    IF @Max >= @Min
	BEGIN
	     --Recursive CTE with counter column for use with EveryN functionality
  		WITH Starter(mv, ctr) AS (
			SELECT @Min, 0 --Root value
			UNION ALL
			SELECT mv + 1, ctr + 1 --Increment values
			FROM Starter --Recursive connection
			WHERE mv + 1 <= @Max --End value
		)
		INSERT @result (number) --Prepare results table
		SELECT mv 
		FROM Starter
		WHERE ctr % @EveryN = 0; --Modulo calculation on selector returns only the values wanted
	END
  RETURN
END
GO


/*******************************************************************************
--Copyright (c) 2022 Mikael Wedham (MIT License)
   -----------------------------------------
   [cron].[internal_ParseRangeExpression]
   -----------------------------------------
   Returns the range of numbers based on a cron range expression
   The results includes the from and to numbers in the expression
   A Range expression is 2 numbers separated by a minus sign : '2-5'

--Copyright (c) 2022 Mikael Wedham

--Permission is hereby granted, free of charge, to any person obtaining a copy
--of this software and associated documentation files (the "Software"), to deal
--in the Software without restriction, including without limitation the rights
--to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--copies of the Software, and to permit persons to whom the Software is
--furnished to do so, subject to the following conditions:
--
--The above copyright notice and this permission notice shall be included in all
--copies or substantial portions of the Software.
--
--THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--SOFTWARE.

   USAGE:
   SELECT * FROM [cron].[internal_ParseRangeExpression]('2-5')
   SELECT * FROM [cron].[internal_ParseRangeExpression]('0-23')
   SELECT * FROM [cron].[internal_ParseRangeExpression]('5-1')       --Ordering is wrong
   SELECT * FROM [cron].[internal_ParseRangeExpression]('25')        --No actual range
   SELECT * FROM [cron].[internal_ParseRangeExpression]('an-error')  --Results in error

Date		Name				Description
----------	-------------		-----------------------------------------------
2022-01-10	Mikael Wedham		+Created v1
*******************************************************************************/
CREATE OR ALTER FUNCTION [cron].[internal_ParseRangeExpression]
(@cron varchar(255)) 
RETURNS @result TABLE (fromnumber int, tonumber int)
AS
BEGIN
	DECLARE @from int 
	DECLARE @to int 

	DECLARE @splitter int
	DECLARE @splitter2 int
	--Find the position of the '-' separator
	SELECT @splitter = CHARINDEX('-', @cron)
	SELECT @splitter2 = CHARINDEX('-', @cron, @splitter + 1)

	--If separator is duplicated or missing, this is not a correct cron part : exit.
	IF (@splitter = 0) OR (@splitter2 > 0)
	BEGIN
	   RETURN
	END

	--Get the 2 parts of the range expression
	SET @from = CAST(SUBSTRING(@cron, 1, @splitter-1) AS int)
    SET @to = CAST(SUBSTRING(@cron, @splitter+1, LEN(@cron)) AS int)

	IF (@to < @from) --Return nothing when numbers are in the wrong order
	BEGIN
	  RETURN
	END

	--Return parts as a table.
	INSERT INTO @result(fromnumber, tonumber) SELECT @from, @to 

	RETURN
END
GO


/*******************************************************************************
--Copyright (c) 2022 Mikael Wedham (MIT License)
   -----------------------------------------
   [cron].[internal_ParseEveryNExpression]
   -----------------------------------------
   Returns the Every N parameter based on a cron partition expression
   The results includes the range/number and the Every N number in the expression
   An Every N expression is a cron expression followed by a division sign : '0-5/2'

   USAGE:
   SELECT * FROM [cron].[internal_ParseEveryNExpression]('0/1')
   SELECT * FROM [cron].[internal_ParseEveryNExpression]('0-23/5')
   SELECT * FROM [cron].[internal_ParseEveryNExpression]('5-1')         --separator missing
   SELECT * FROM [cron].[internal_ParseEveryNExpression]('error/test')  --Results in error

Date		Name				Description
----------	-------------		-----------------------------------------------
2022-01-10	Mikael Wedham		+Created v1
*******************************************************************************/
CREATE OR ALTER FUNCTION [cron].[internal_ParseEveryNExpression]
(@cron varchar(255)) 
RETURNS @result TABLE (cron varchar(255), everyn int)
AS
BEGIN
	DECLARE @cronpattern varchar(255)
	DECLARE @modulo int

	DECLARE @splitter int
	DECLARE @splitter2 int
	--Find the position of the '/' separator
	SELECT @splitter = CHARINDEX('/', @cron)
	SELECT @splitter2 = CHARINDEX('/', @cron, @splitter + 1)

	--If separator is duplicated or missing, this is not a correct cron part : exit.
	IF (@splitter = 0) OR (@splitter2 > 0)
	BEGIN
	   RETURN
	END

	--Get the first part, that is the base cron pattern
	SET @cronpattern = SUBSTRING(@cron, 1, @splitter-1)
	--Get the partition/EveryN value
    SET @modulo = CAST(SUBSTRING(@cron, @splitter+1, LEN(@cron)) AS int)

	--Return the new pattern and the EveryN parameter separately
	INSERT INTO @result(cron, everyn) SELECT @cronpattern, @modulo

	RETURN
END
GO



/*******************************************************************************
--Copyright (c) 2022 Mikael Wedham (MIT License)
   -----------------------------------------
   [cron].[internal_ParseFieldPart]
   -----------------------------------------
   Returns a list of numbers based on a cron expression field part
   A field part is ONE of the comma separated items in a cron field.
   This function is a wrapper function for the *ParseEveryN* and *ParseRange* functions

   USAGE:
   SELECT * FROM [cron].[internal_ParseFieldPart]('0', 0, 10)            --Zero 
   SELECT * FROM [cron].[internal_ParseFieldPart]('*', 0, 10)            --All numbers between 0 and 10
   SELECT * FROM [cron].[internal_ParseFieldPart]('0-20/5', 0, 20)       --Every 5 numbers from 0 to 20
   SELECT * FROM [cron].[internal_ParseFieldPart]('* / 5', 0, 20)        --Every 5 numbers from 0 to 20 (extra spaces added due to T-SQL comments)
   SELECT * FROM [cron].[internal_ParseFieldPart]('5-1', 0, 100)         --wrong order, no result
   SELECT * FROM [cron].[internal_ParseFieldPart]('error/test', 0, 100)  --Results in error


Date		Name				Description
----------	-------------		-----------------------------------------------
2022-01-10	Mikael Wedham		+Created v1
*******************************************************************************/
CREATE OR ALTER FUNCTION [cron].[internal_ParseFieldPart]
(@cron varchar(255), @min int, @max int) 
RETURNS @result TABLE (number int)
AS
BEGIN

 DECLARE @start int 
 DECLARE @stop int 
 DECLARE @EveryN int = 1
 DECLARE @cronpart varchar(255)

 --Get a writable copy of the cron expression
 SET @cronpart = @cron
 
 --If expression contains /, it is a partition/EveryN expression
 IF (CHARINDEX('/', @cron) > 0)
 BEGIN
    --Set the new cron expression and keep the EveryN value
	SELECT @cronpart = cron, @EveryN = everyn 
	FROM [cron].[internal_ParseEveryNExpression](@cron)
 END 
 
 --If expression contains -, it is a range expression
 IF (CHARINDEX('-', @cronpart) > 0)
 BEGIN
    --Get the start/stop values from the range.
	SELECT @start = fromnumber, @stop = tonumber 
	FROM [cron].[internal_ParseRangeExpression](@cronpart)
 END
 
 --A star indicates full range (between min and max)
 IF (@cronpart = '*')
 BEGIN
	SELECT @start = @min, @stop = @max
 END

 --If the part is a single number, min and max are equal
 IF (ISNUMERIC(@cronpart) = 1)
 BEGIN
    SELECT @start = CAST(@cronpart AS int), @stop = CAST(@cronpart AS int)
 END

 --Prepare the results based on the full parsing of the cron expression
 INSERT INTO @result(number) 
 SELECT number 
 FROM [cron].[internal_GetNumbers](@start, @stop, @EveryN)
 
 RETURN
END
GO





/*******************************************************************************
--Copyright (c) 2022 Mikael Wedham (MIT License)
   -----------------------------------------
   [cron].[internal_ParseField]
   -----------------------------------------
   Returns a list of numbers based on a cron expression field
   A field is the base of the CRON expression
   This function is a wrapper function for the [internal_ParseFieldPart] function

   USAGE:
   SELECT * FROM [cron].[internal_ParseField]('0', 0, 10)            --Zero 
   SELECT * FROM [cron].[internal_ParseField]('0,5,7', 0, 10)        --Zero, 5 and 7
   SELECT * FROM [cron].[internal_ParseField]('1-4,3,8', 0, 10)      --1-4, 8 and 3 (duplicate) 
   SELECT * FROM [cron].[internal_ParseField]('*', 0, 10)            --All numbers between 0 and 10
   SELECT * FROM [cron].[internal_ParseField]('0-20/5', 0, 20)       --Every 5 numbers from 0 to 20
   SELECT * FROM [cron].[internal_ParseField]('0-20/5,18', 0, 20)    --Every 5 numbers from 0 to 20 and also 18
   SELECT * FROM [cron].[internal_ParseField]('5-1', 0, 100)         --wrong order, no result
   SELECT * FROM [cron].[internal_ParseField]('5,error/test', 0, 100)  --Results in error

Date		Name				Description
----------	-------------		-----------------------------------------------
2022-01-10	Mikael Wedham		+Created v1
*******************************************************************************/
CREATE OR ALTER FUNCTION [cron].[internal_ParseField]
(@cron varchar(255), @min int, @max int) 
RETURNS @result TABLE (numbers int)
AS
BEGIN
 --Unsorted list of parts in one segment
 DECLARE @parts TABLE (segment varchar(255))

 DECLARE @writablecron varchar(255) = @cron
 DECLARE @part varchar(255) 
 DECLARE @pos int

 WHILE CHARINDEX(',', @writablecron) > 0
 BEGIN

  SELECT @pos = CHARINDEX(',', @writablecron)
  SELECT @part = SUBSTRING(@writablecron, 1, @pos - 1)
  
  INSERT INTO @parts 
  SELECT @part

  SELECT @writablecron = SUBSTRING(@writablecron, @pos+1, LEN(@writablecron)-@pos)

 END
 INSERT INTO @parts 
 SELECT @writablecron


 --Return a distinct list of numbers that match the aggregated cron segment
 INSERT INTO @result(numbers) 
 SELECT DISTINCT s.number  
 FROM @parts p CROSS APPLY [cron].[internal_ParseFieldPart](p.segment, @min, @max) s
 
 RETURN
END
GO


/*******************************************************************************
--Copyright (c) 2022 Mikael Wedham (MIT License)
   -----------------------------------------
   [cron].[NormalizeExpression]
   -----------------------------------------
   Returns a cron expression without repeating spaces
   , where the month/day texts are replaced by numbers.

Date		Name				Description
----------	-------------		-----------------------------------------------
2022-01-10	Mikael Wedham		+Created v1
*******************************************************************************/
CREATE OR ALTER FUNCTION [cron].[NormalizeExpression]
(@cron varchar(255))
RETURNS varchar(255)
AS
BEGIN 
	DECLARE @cronexpression varchar(255)
	SET @cronexpression = @cron

	--Remove repeating whitespaces
	WHILE CHARINDEX('  ',@cronexpression) > 0
	BEGIN
		SET @cronexpression = REPLACE(@cronexpression, '  ',' ')
	END

	--Replace Month texts with numeric values
	SET @cronexpression = REPLACE(UPPER(@cronexpression), 'JAN', '1')
	SET @cronexpression = REPLACE(UPPER(@cronexpression), 'FEB', '2')
	SET @cronexpression = REPLACE(UPPER(@cronexpression), 'MAR', '3')
	SET @cronexpression = REPLACE(UPPER(@cronexpression), 'APR', '4')
	SET @cronexpression = REPLACE(UPPER(@cronexpression), 'MAY', '5')
	SET @cronexpression = REPLACE(UPPER(@cronexpression), 'JUN', '6')
	SET @cronexpression = REPLACE(UPPER(@cronexpression), 'JUL', '7')
	SET @cronexpression = REPLACE(UPPER(@cronexpression), 'AUG', '8')
	SET @cronexpression = REPLACE(UPPER(@cronexpression), 'SEP', '9')
	SET @cronexpression = REPLACE(UPPER(@cronexpression), 'OCT', '10')
	SET @cronexpression = REPLACE(UPPER(@cronexpression), 'NOV', '11')
	SET @cronexpression = REPLACE(UPPER(@cronexpression), 'DEC', '12')

	--Replace day texts with numeric values
	SET @cronexpression = REPLACE(UPPER(@cronexpression), 'SUN', '0')
	SET @cronexpression = REPLACE(UPPER(@cronexpression), 'MON', '1')
	SET @cronexpression = REPLACE(UPPER(@cronexpression), 'TUE', '2')
	SET @cronexpression = REPLACE(UPPER(@cronexpression), 'WED', '3')
	SET @cronexpression = REPLACE(UPPER(@cronexpression), 'THU', '4')
	SET @cronexpression = REPLACE(UPPER(@cronexpression), 'FRI', '5')
	SET @cronexpression = REPLACE(UPPER(@cronexpression), 'SAT', '6')

	RETURN @cronexpression
END
GO

/*******************************************************************************
--Copyright (c) 2022 Mikael Wedham (MIT License)
   -----------------------------------------
   [cron].[GetPreviousSchedule]
   -----------------------------------------
   Gets the next run date and time for this cron expression.
   If this functions result is larger than the value of the last run time
   , that means the schedule is overdue and sould be run immediately.

   USAGE:
   SELECT * FROM [cron].[GetPreviousSchedule]('* * * * *')                  --Each minute
   SELECT * FROM [cron].[GetPreviousSchedule]('59 23 31 12 5')              --One minute  before the end of year if the last day of the year is Friday
   SELECT * FROM [cron].[GetPreviousSchedule]('45 17 7 6 * ')               --Every  year, on June 7th at 17:45 
   SELECT * FROM [cron].[GetPreviousSchedule]('* / 15 * / 6 1,15,31 * 1-5')  --At 00:00, 00:15, 00:30, 00:45, 06:00, 06:15, 06:30, 06:45, 12:00, 12:15, 12:30, 12:45, 18:00, 18:15, 18:30, 18:45, on 1st, 15th or  31st of each  month, but not on weekends
   SELECT * FROM [cron].[GetPreviousSchedule]('0 12 * * 1-5')               --At midday on weekdays

Date		Name				Description
----------	-------------		-----------------------------------------------
2022-01-10	Mikael Wedham		+Created v1
2022-01-11  Mikael Wedham       Changed return type to table for consistency when querying
*******************************************************************************/
CREATE OR ALTER FUNCTION [cron].[GetPreviousSchedule]
(@cron varchar(255)) 
RETURNS @result TABLE (scheduledtime datetime)
AS
BEGIN
	--Create writable cron
	DECLARE @cronexpression varchar(255)
	SET @cronexpression = [cron].[NormalizeExpression](@cron)

	DECLARE @minute varchar(255)
	DECLARE @minutepos int
	DECLARE @hour varchar(255)
	DECLARE @hourpos int
	DECLARE @dayofmonth varchar(255)
	DECLARE @dayofmonthpos int
	DECLARE @month varchar(255)
	DECLARE @monthpos int
	DECLARE @dayofweek varchar(255)

	--Get positions of all parts 
	SELECT @minutepos = CHARINDEX(' ', @cronexpression, 1) - 1
	SELECT @hourpos = CHARINDEX(' ', @cronexpression, @minutepos+2) - 1
	SELECT @dayofmonthpos = CHARINDEX(' ', @cronexpression, @hourpos+2) - 1
	SELECT @monthpos = CHARINDEX(' ', @cronexpression, @dayofmonthpos+2) - 1

	--Extract the different parts of the cron expression
	SELECT @minute = SUBSTRING(@cronexpression, 1, @minutepos) 
	, @hour = SUBSTRING(@cronexpression, @minutepos + 2, @hourpos-@minutepos) 
	, @dayofmonth = SUBSTRING(@cronexpression,@hourpos + 2 , @dayofmonthpos-@hourpos) 
	, @month = SUBSTRING(@cronexpression, @dayofmonthpos + 2, @monthpos-@dayofmonthpos) 
	, @dayofweek = SUBSTRING(@cronexpression,@monthpos + 2, LEN(@cronexpression)-@monthpos+1) 

		--Get a list of all minutes in the expression
		DECLARE @tMinutes TABLE (value int)
		INSERT @tMinutes (value) SELECT numbers FROM [cron].[internal_ParseField](@minute, 0, 59);

		--Get a list of all hours in the expression
		DECLARE @tHours TABLE (value int)
		INSERT @tHours (value) SELECT numbers FROM [cron].[internal_ParseField](@hour, 0, 23);

		--Get a list of all days of the month in the expression
		DECLARE @tDays TABLE (value int)
		INSERT @tDays (value) SELECT numbers FROM [cron].[internal_ParseField](@dayofmonth, 1, 31);

		--Get a list of all months in the expression
		DECLARE @tMonths TABLE (value int)
		INSERT @tMonths (value) SELECT numbers FROM [cron].[internal_ParseField](@month, 1, 12);

		--Get a list of all allowed days of the week in the expression
		DECLARE @tWeekdays TABLE (value int)
		INSERT @tWeekdays (value) SELECT numbers FROM [cron].[internal_ParseField](@dayofweek, 0, 7);

		--Get a value in order to work with all DATEFIRST settings
		DECLARE @deltaday int
		SELECT @deltaday = @@DATEFIRST - 1

	--Do not calculate more days than needed (rough estimate)
	DECLARE @days int = 7
	
    --Contains all dates that should have at least one scheduled time
	DECLARE @tdates TABLE (value date)
	
	WHILE (SELECT COUNT(*) FROM @tdates) < 1 OR @days > 2500000
	BEGIN
		;WITH datenum AS --Get a number list for the estimated number of days
			(SELECT number = 1 
			   UNION ALL 
			 SELECT number = number - 1 
			 FROM datenum 
			 WHERE number > -@days)
		,datesequence AS --Create the date list, with the last run date as the base.
			(SELECT number
				  , dt = DATEADD(DAY, number, GETDATE())
			 FROM datenum )

		--Get all the dates from the date list that match the date filter
		--Modulo accounts for overflowing daynumbers if DATEFIRST > 1
		INSERT INTO @tdates(value)
		SELECT dates.dt 
		FROM datesequence dates INNER JOIN @tMonths m ON m.value = DATEPART(MONTH, dates.dt) --Only get dates for the selected months
			INNER JOIN @tDays d ON d.value = DATEPART(DAY, dates.dt) --Only get dates for the selected day of month
			INNER JOIN @tWeekdays w ON w.value = (DATEPART(WEEKDAY, dates.dt) + @deltaday) % 7 --Only get dates for the selected day of week. 
		option (maxrecursion 0)

		SET @days = @days * 2
    END

	--Contains all scheduled times
	DECLARE @ttimes TABLE (value time(0))

	--Generate all time values, by combining all hours and all minutes
	INSERT INTO @ttimes(value)
	SELECT t = RIGHT('0' + CAST(h.value as varchar(2)), 2) + ':' + RIGHT('0' + CAST(m.value as varchar(2)), 2) + ':00'
	FROM @tHours h CROSS JOIN @tMinutes m

	;WITH allScheduledTimes AS --Generate datetime values for all dates and times
	  ( SELECT schedule = CAST(CONVERT(varchar(20), d.value, 121) + ' ' + CONVERT(varchar(20), t.value) AS datetime)
	    FROM @tdates d CROSS JOIN @ttimes t)
    , PreviousSchedule AS --Get the next expected schedule
	(SELECT TOP(1)  schedule
	FROM allScheduledTimes
	WHERE schedule < GETDATE()
	ORDER BY schedule DESC)

	INSERT INTO @result(scheduledtime)
	SELECT schedule
	FROM PreviousSchedule

	RETURN  

END
GO




/*******************************************************************************
--Copyright (c) 2022 Mikael Wedham (MIT License)
   -----------------------------------------
   [cron].[GetNextSchedule]
   -----------------------------------------
   Gets the next run dates and times for this cron expression
   The @MaxScheduleCount will return UP TO the maximum number
   of rows, but it can return less.

   USAGE:
   SELECT * FROM [cron].[GetNextSchedule]('* * * * *' , 5)                   --Each minute, Get 5 rows
   SELECT * FROM [cron].[GetNextSchedule]('59 23 31 12 5', 1)                --One minute  before the end of year if the last day of the year is Friday
   SELECT * FROM [cron].[GetNextSchedule]('45 17 7 6 * ', 2)                 --Every  year, on June 7th at 17:45 , Get 2 rows
   SELECT * FROM [cron].[GetNextSchedule]('* / 15 * / 6 1,15,31 * 1-5', 10)  --At 00:00, 00:15, 00:30, 00:45, 06:00, 06:15, 06:30, 06:45, 12:00, 12:15, 12:30, 12:45, 18:00, 18:15, 18:30, 18:45, on 1st, 15th or  31st of each  month, but not on weekends , Get 10 rows
   SELECT * FROM [cron].[GetNextSchedule]('0 12 * * 1-5', 14)                --At midday on weekdays, Get 14 rows

Date		Name				Description
----------	-------------		-----------------------------------------------
2022-01-04	Mikael Wedham		+Created v1
*******************************************************************************/
CREATE OR ALTER FUNCTION [cron].[GetNextSchedule]
(@cron varchar(255), @MaxScheduleCount int) 
RETURNS @result TABLE (scheduledtime datetime)
AS
BEGIN
	DECLARE @nextschedule datetime

	--Create writable cron
	DECLARE @cronexpression varchar(255)
	SET @cronexpression = [cron].[NormalizeExpression](@cron)

	DECLARE @minute varchar(255)
	DECLARE @minutepos int
	DECLARE @hour varchar(255)
	DECLARE @hourpos int
	DECLARE @dayofmonth varchar(255)
	DECLARE @dayofmonthpos int
	DECLARE @month varchar(255)
	DECLARE @monthpos int
	DECLARE @dayofweek varchar(255)

	--Get positions of all parts 
	SELECT @minutepos = CHARINDEX(' ', @cronexpression, 1) - 1
	SELECT @hourpos = CHARINDEX(' ', @cronexpression, @minutepos+2) - 1
	SELECT @dayofmonthpos = CHARINDEX(' ', @cronexpression, @hourpos+2) - 1
	SELECT @monthpos = CHARINDEX(' ', @cronexpression, @dayofmonthpos+2) - 1

	--Extract the different parts of the cron expression
	SELECT @minute = SUBSTRING(@cronexpression, 1, @minutepos) 
	, @hour = SUBSTRING(@cronexpression, @minutepos + 2, @hourpos-@minutepos) 
	, @dayofmonth = SUBSTRING(@cronexpression,@hourpos + 2 , @dayofmonthpos-@hourpos) 
	, @month = SUBSTRING(@cronexpression, @dayofmonthpos + 2, @monthpos-@dayofmonthpos) 
	, @dayofweek = SUBSTRING(@cronexpression,@monthpos + 2, LEN(@cronexpression)-@monthpos+1) 

		--Get a list of all minutes in the expression
		DECLARE @tMinutes TABLE (value int)
		INSERT @tMinutes (value) SELECT numbers FROM [cron].[internal_ParseField](@minute, 0, 59);

		--Get a list of all hours in the expression
		DECLARE @tHours TABLE (value int)
		INSERT @tHours (value) SELECT numbers FROM [cron].[internal_ParseField](@hour, 0, 23);

		--Get a list of all days of the month in the expression
		DECLARE @tDays TABLE (value int)
		INSERT @tDays (value) SELECT numbers FROM [cron].[internal_ParseField](@dayofmonth, 1, 31);

		--Get a list of all months in the expression
		DECLARE @tMonths TABLE (value int)
		INSERT @tMonths (value) SELECT numbers FROM [cron].[internal_ParseField](@month, 1, 12);

		--Get a list of all allowed days of the week in the expression
		DECLARE @tWeekdays TABLE (value int)
		INSERT @tWeekdays (value) SELECT numbers FROM [cron].[internal_ParseField](@dayofweek, 0, 7);

		--Get a value in order to work with all DATEFIRST settings
		DECLARE @deltaday int
		SELECT @deltaday = @@DATEFIRST - 1

	--Do not calculate more days than needed (rough estimate)
	DECLARE @days int = 7
	
    --Contains all dates that should have at least one scheduled time
	DECLARE @tdates TABLE (value date)
	
	WHILE (SELECT COUNT(*) FROM @tdates) <= @MaxScheduleCount OR @days > 2500000
	BEGIN
		;WITH datenum AS --Get a number list for the estimated number of days
			(SELECT number = 0 
			   UNION ALL 
			 SELECT number = number + 1 
			 FROM datenum 
			 WHERE number < @days)
		,datesequence AS --Create the date list, with the last run date as the base.
			(SELECT number
				  , dt = DATEADD(DAY, number, GETDATE())
			 FROM datenum )

		--Get all the dates from the date list that match the date filter
		--Modulo accounts for overflowing daynumbers if DATEFIRST > 1
		INSERT INTO @tdates(value)
		SELECT dates.dt 
		FROM datesequence dates INNER JOIN @tMonths m ON m.value = DATEPART(MONTH, dates.dt) --Only get dates for the selected months
			INNER JOIN @tDays d ON d.value = DATEPART(DAY, dates.dt) --Only get dates for the selected day of month
			INNER JOIN @tWeekdays w ON w.value = (DATEPART(WEEKDAY, dates.dt) + @deltaday) % 7 --Only get dates for the selected day of week. 
		option (maxrecursion 0)

		SET @days = @days * 2
    END

	--Contains all scheduled times
	DECLARE @ttimes TABLE (value time(0))

	--Generate all time values, by combining all hours and all minutes
	INSERT INTO @ttimes(value)
	SELECT t = RIGHT('0' + CAST(h.value as varchar(2)), 2) + ':' + RIGHT('0' + CAST(m.value as varchar(2)), 2) + ':00'
	FROM @tHours h CROSS JOIN @tMinutes m

	;WITH allScheduledTimes AS --Generate datetime values for all dates and times
	  ( SELECT schedule = CAST(CONVERT(varchar(20), d.value, 121) + ' ' + CONVERT(varchar(20), t.value) AS datetime)
	    FROM @tdates d CROSS JOIN @ttimes t)
    , NextSchedule AS --Get the next expected schedule
	(SELECT DISTINCT schedule
	FROM allScheduledTimes
	WHERE schedule >= GETDATE()
	)
	INSERT INTO @result
	SELECT TOP(@MaxScheduleCount) schedule
	FROM NextSchedule
    ORDER BY schedule

RETURN  

END
GO


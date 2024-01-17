# cron
## A T-SQL library for using and parsing CRON scheduling strings

This library consists of three T-SQL User Defined Functions 

Also in the library is an additional coulple of UDFs for internal use. And two helper tables to increase performance of the parsing.

It is written for the basic cron syntax with 5 fields. 
- [cron].[GetNextSchedule]
- [cron].[GetNextScheduleAfter]
- [cron].[GetPreviousSchedule]

The library is licensed under the [MIT License](LICENSE) 

---
###### Quote from [https://crontab.guru/](https://crontab.guru/)

#### The time and date fields are:

Field {Allowed values}
1. minute {0-59}
2. hour {0-23}
3. day of month {1-31}
4. month {1-12} (or names, see below)
5. day of week {0-7} (0 or 7 is Sunday, or use names)

---

>A field may contain an asterisk (*), which always stands for "first-last".

>Ranges of numbers are allowed. Ranges are two numbers separated with a hyphen. The specified range is inclusive. For example, 8-11 for an 'hours' entry specifies execution at hours 8, 9, 10, and 11.

>Lists are allowed. A list is a set of numbers (or ranges) separated by commas. Examples: "1,2,5,9", "0-4,8-12".

>Step values can be used in conjunction with ranges. Following a range with "/<number>" specifies skips of the number's value through the range. For example, "0-23/2" can be used in the 'hours' field to specify command execution for every other hour (the alternative in the V7 standard is "0,:2,:4,:6,:8,:10,:12,:14,:16,:18,:20,:22"). Step values are also permitted after an asterisk, so if specifying a job to be run every two hours, you can use "*/2".

>Names can also be used for the 'month' and 'day of week' fields. Use the first three letters of the particular day or month (case does not matter). Ranges of names are not allowed.

---
#### A full description of what is used can be found at crontab.guru:

https://crontab.guru/crontab.5.html

This site is also where you find example cron expressions to try out yourself.

---
#### Partial example usage is available in the header of the UDFs:


 
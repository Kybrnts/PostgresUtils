Description
-----------
LastPGErrs is a simple script to periodically retrieve all matching messages redirected by PostgreSQL "Logging 
Collector" process. When enabled, this process runs in background, captures log messages sent to STDERR and redirects
them into specific log files that can be rotated. All this works according the following PostgreSQL configuration
parameters found only on postgresql.conf:
* logging_collector (boolean): enables the logging collector;
* log_directory (string): specifies the logs container directory path (default value is pg_log);
* log_filename (string): specifies the name names for created log files.
For more information on the subject, please visit:
https://www.postgresql.org/docs/current/static/runtime-config-logging.html
LastPGErrs will therefore keep track of the number of messages that matched against the given pattern in its previous
execution and decide if there are new matching ones by comparing that number with the number of currently matching ones,
sending to STDOUT only the new ones. In additon, to avoid loosing messages it will reset the previously matched number
upon log file rotation (i.e. new log file is in use). But to be aware of that rotation it will aslo need to keep track
of the last log file used to find matching messages.

Workflow
--------
01. Start by getting the PID of PostgreSQL's Logging Collector. If it is not running finish w/errors;
02. Then read the last PostgreSQL log filename used from file. If this fails, finish w/errors;
03. Also read the last number of errors found in previous file name from file, finishing w/errors when not possible;
04. Continue by counting the current number of errors found in that file. If this is not possible, throw a warning
    explaining that some errors might be lost from previous log rotation and continue w/step 06;
05. Compare the current number of errors in previous log file w/the previous number. If the difference "d" is greater
    than zero then display the last d error messages from that file.
06. Get the current log filename used by Logging Collector. If it is not possible, finish w/errors;
07. Compare the currently used log filename w/that read in step 02. If it is the same continue w/step ??.
08. Now that Logging Collector is using a new log file, count the number of errors found in it, finishing w/errors when
    not possible.
09. Assign the current number of errors found in the new log file to the difference "d" between the current and previous
    execution.
10. 

Configuration
-------------


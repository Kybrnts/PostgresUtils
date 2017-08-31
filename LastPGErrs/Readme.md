Description
-----------
LastPGErrs is a simple script to periodically retrieve all matching messages redirected by PostgreSQL's "Logging 
Collector" process. When enabled, this process runs in background, captures log messages sent to STDERR and redirects
them into specific log files that can be rotated. All this works according the following PostgreSQL configuration
parameters found only on postgresql.conf:
* logging_collector (boolean): enables the logging collector;
* log_directory (string): specifies the logs container directory path (default value is pg_log);
* log_filename (string): specifies the name names for created log files.

For more information on the subject, please visit below links:
* https://www.postgresql.org/docs/current/static/runtime-config-logging.html
* https://www.openscg.com/2016/05/helpful-postgresql-logging-and-defaults/

LastPGErrs will therefore keep track of the number of messages that matched against the given pattern in its previous
execution and decide if there are new matching ones by comparing that number with the number of currently matching ones,
sending to STDOUT only the new ones. In additon, to avoid loosing messages it will reset the previously matched number
upon log file rotation (i.e. new log file is in use). But to be aware of that rotation it will aslo need to keep track
of the last log file used to find matching messages.

Workflow
--------
01. Make sure that current user is postgres, otherwise finish w/errors;
02. Then read the last log filename used by the Logging Collector from file. If this fails, finish w/errors;
03. Also read the last number of matching lines found during previous execution from file, finishing with
    errors when not possible;
04. Continue by counting the current number matches found in previous log file. If this is not possible, throw a warning
    explaining that some errors might be lost from previous log rotation and continue w/step 07;
05. Compare the current number of errors in previous log file w/the previous number from step 03. If the difference "d"
    is >0 then display the last "d" error messages from that file or finish w/errors if that's not possible;
06. Update the last number of matches found in previous execution in file adding previous "d" to its contained number;
07. Find the PID of PostgreSQL's Logging Collector. If it is not running finish w/errors;
08. Get the current log filename used by Logging Collector. If it is not possible, finish w/errors;
09. Compare the currently used log file w/that read in step 02. If it is the same finish;
10. Now that Logging Collector is using a new log file, Update last the last log filename used by the Logging Collector.
    If this fails, finish w/errors;
11. Also count all matching lines found in new log file, finishing w/errors if that fails;
12. Display last previously counted matching lines from new log file, finishing w/errors if that fails;
13. Update the last number of matches found in previous execution in file with the number found in 10.

Flow repeated tasks:
* Display messages to STODUT;
* Display error messages to STDERR;
* Read first line from file, given its path;
* Update first line in file, given its path and line content;
* Count all matching lines from file given a pattern and its path;
* Display last N matching lines from file given N, a pattern and its path;

Global/config. parameters:
* PostgreSQL system user;
* Logging Collector process name;
* PostgreSQL logs directory;
* Last log filename used by Logging Collector log file path;
* Last number of matching messages found in last log file used by Logging Collector log file path;

Installation
------------
01. Deploy script in /usr/local/bin;
02. Set owner:group as root:postgres for script's file;
03. Set mode as 750 for script's file;
04. Allow your monitor user to run the script as postgres

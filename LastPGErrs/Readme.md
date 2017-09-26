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
execution and decide if there are new ones by comparing that number with the number of currently matching messages,
sending to STDOUT only the new. In additon, to avoid loosing messages it will reset the previously matched number upon
log file rotation (i.e. new log file is in use). But to be aware of that rotation it will aslo need to keep track of the
last log file used to find matching messages.

Workflow
--------
Below Workflow makes several assumptions including:
* The capability of finding which files within a directory are in use by a process given its ID. This is usually
  achieved by a wise use of either the lsof or fuser acilities, or by listing the contents of /proc/$PID/fd. By doing
  this, we avoid using dates and timestamps for the search.
* The existence of a Pidfile. That allows to point to a single running instance of PostgreSQL in order to find its
  child Logging Collector process to do the follow up. The use of a pidfile is supported by postgresql.conf
  "external_pid_file" parameter, and we will assume that a single instance of PostgreSQL will be followed up through its
  child Collector by a given instance of this script.

01. Make sure that current user is postgres, otherwise finish w/errors;
02. Then read the last log filename used by the Logging Collector from file. If this fails because file is empty or does
    not exists, then go to step 07. Otherwise finish w/errors;
03. Also read the last number of matching lines found during previous execution from file, if this is not possible
    because file is empty or does not exists, go to step 07. Otherwise finishing with errors;
04. Now count the current number of matches found in previously used log file. If this is not possible, throw a warning
    explaining that some errors might be lost from previous log rotation and continue w/step 07;
05. Compare the current number of errors "C" in previous log file w/the previous number "P" from step 03. If C - P > 0,
    display all current error messages, ignoring the first "P" ones (new ones only).
06. Update the last number of matches found in previous execution in file adding "C - P" to its contained number;
07. Find the PID of PostgreSQL's Logging Collector. If it is not possible to find a unique ID, finish w/errors;
08. Get the current log filename used by Logging Collector. If it is not possible, finish w/errors;
09. Compare the currently used log file w/that read in step 02. If it is the same finish (we have already processed it);
10. Now that Logging Collector is using a new log file since our previous execution, create/update last file log
    file with new log filename in its first line. If this update fails finish w/errors;
11. Also count all matching lines found in new log file, finishing w/errors if that fails;
12. Display last previously counted matching lines from new log file, finishing w/errors if that fails;
13. Update the last number of matches found in previous execution in file with the number found in 10.

Flow remarkable tasks:
* Display messages to STODUT;
* Display error messages to STDERR;
* Read first line from file, given its path;
* Update first line in file, given its path and line content;
* Count all matching lines from file given a pattern and its path;
* Display last matching lines from file, ignoring the first N ones; given N, a pattern and its path;
* Find the log file used by PostgreSQL Logging Collector.

Global/config. parameters:
* PostgreSQL system user;
* Logging Collector process name;
* PostgreSQL logs directory;
* PostgreSQL Pidfile path (previously defined in postgresql.conf);
* Last log filename used by Logging Collector log file path;
* Last number of matching messages found in last log file used by Logging Collector log file path;
* Pattern string for log file lines to match with;

Installation
------------
01. Deploy script in /usr/local/bin;
02. Set owner:group as root:postgres for script's file;
03. Set mode as 750 for script's file;
04. Allow your monitor user to run the script as postgres;

Authors
-------
Written by Kybernetes <correodelkybernetes@gmail.com>
Reviewed by shd128 (https://github.com/shd128)
         


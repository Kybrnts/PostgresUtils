#: Title       : Pgprofile.sh
#: Date        : 2017-10-05
#: Author      : "Kybernetes" <correodelkybernetes@gmail.com>
#: Version     : 1.2.0
#: Description : Dash script file
#:             : Postgres user's shell startup file providing version agnostic control over PostgreSQL service for the
#:             : postgres user. Control is provided though pg_service() which accepts usual init.d parameters.
#: Options     : N/A
#: Intallation : Deploy it within /etc/profile.d or equivalent, however it might cause problems with vendor-provided
#:             : postgres's $HOME/.bash_profile, so replace it with a default bash_profile.
#: Copyright   : To the extent possible under law, the author(s) have dedicated all copyright and related and
#:             : neighboring rights to this software to the  public domain worldwide. This software is distributed
#:             : without any warranty. You should have received a copy of the CC0 Public Domain Dedication along with
#:             : this software. If not, please visit http://creativecommons.org/publicdomain/zero/1.0/.
##
## -- Globals ----------------------------------------------------------------------------------------------------------
PGVERS=9.5                         ## PostgreSQL version (try to be version agnostic)
PGDATA=/var/lib/pgsql/$PGVERS/data ## Database container
PGBIN=/usr/pgsql-$PGVERS/bin       ## PostgreSQL ported binaries container
##
# Provide init-like commands
## Check requirements, if one is missing do not load any function/variable:
## * There must be a terminal allocated for tools to be loaded to environment (only for interactive remote shells);
## * User mut be postgres (provide utilities only for that user);
## * A valid PostgreSQL installation must be present (check for $PGDATA, $PGBIN/*);
if [ -t 0 ] &&\
   [ "$USER" = postgres ] &&\
   type pgrep >/dev/null 2>&1 &&\
   type sleep >/dev/null 2>&1 &&\
   [ -d "$PGDATA" -a -r "$PGDATA" -a -x "$PGDATA" ] &&\
   [ -f $PGBIN/pg_ctl -a -x $PGBIN/pg_ctl ] &&\
   [ -f $PGBIN/postgresql${PGVERS%.*}${PGVERS#*.}-check-db-dir -a\
     -x $PGBIN/postgresql${PGVERS%.*}${PGVERS#*.}-check-db-dir ]
then
    ##
    ## Set path environment if needed
    case $PATH in
        */usr/local/pgsql/bin*) ;;
        *) PATH=$PATH:/usr/local/pgsql/bin ;;
    esac
    ##
    ## Enable system to find the man documentation
    case $MANPATH in
        */usr/local/pgsql/share/man*) ;;
        *) MANPATH=$MANPATH:/usr/local/pgsql/share/man ;;
    esac
    readonly PGDATA PGVERS PGBIN
    export PGDATA PGVERS PGBIN PATH MANPATH
    ##
    ## -- Auxiliary functions ------------------------------------------------------------------------------------------
    stdmsg() { #@ DESCRIPTION: Print messages to STDOUT
               #@ USAGE: stdmsg [ MSG ... ]
        [ "${1+X}" = X ] && printf "%s\n" "$@"
    }
    errmsg() { #@ DESCRIPTION: Print messages to STDERR prefixed by an error stamp
               #@ USAGE: stderr [ MSG ... ]
        stdmsg ${1+"Error! $@"} >&2
    }
    valpid() { #@ DESCRIPTION: Checks if $1 contains a valid PID number
               #@ USAGE: stderr [ MSG ... ]
        case $1 in
            "") return 1 ;;
            *[!0-9]*) return 2 ;;
        esac
    }
    readonly stdmsg errmsg valpid
    export stdmsg errmsg valpid
    ##
    ## -- Core functions -----------------------------------------------------------------------------------------------
    _PGPID=
    getPgPID() { #@ DESCRIPTION: Looks for already running instances of PostgreSQL. On success, it writes instance's PID
                 #@              in $1 and return 0. On failure, returns >0.
                 #@ USAGE: getPgPID NAME
        _PGPID=$(pgrep -f "$PGBIN/postgres" 2>/dev/null)
        case $? in
            1) ## Pgrep failed but from callers prerpective this might not be an error, e.g. when called by doStart
                return 1 ;;
            ^[0]*) ## As per Pgrep manual this should never happen (2 means syntax error, 3 Fatal and >3 is unexpected)
                return 2 ;;
        esac
        eval "$1=\"\$_PGPID\"" ## Assign value to given name. /!\ - Warning! $1 must be a valid shell name /!\
    }
    doStop() { #@ DESCRIPTION: Tries to stop the single currently running instance of postgreSQL. It is simply a wrapper
               #@              for the default binary used by service's unit file w/the exact same options/artuments.
               #@              Returns 1 on falure and 0 on success.
               #@ USAGE: doStop
        local pgpid
        stdmsg "Searching for running postgresql-${PGVERS} process to stop.."
        sleep 1 2>/dev/null
        ## Search for a running process, if not found finish. ----------------------------------------------------------
        getPgPID pgpid ## Here an exit status of 0 is the desired one
        case $? in
            1) ## No process found to stop (trivial error)
                errmsg "No process found to stop."
                return 1 ;;
            [^0]*) ## Unexpected error during process search. Can't be sure about it, so ask user to perform search
                errmsg "Unexpected error while searching for process."
                stdmsg "Please, try a manual search."
                return 2 ;;
            0) ## Process found!!, validate it
                if ! valpid "$pgpid"; then ## Invalid search result. Can't be sure about it, so request user to search
                    errmsg "Wrong PID value retreived for process."
                    stdmsg "Please, try a manual search."
                    return 3
                fi ;;
        esac
        ## Valid process id found so, try to stop it -------------------------------------------------------------------
        stdmsg "Process found on PID=$pgpid"\
               "Stopping postgresql-${PGVERS} process.."
        if ! $PGBIN/pg_ctl stop -D "$PGDATA" -s -m fast; then
            errmsg "Failed to stop process. Try manually."
            return 4
        fi
        sleep 2 2>/dev/null ## Allow some time for process to stop
        ## Did the process really finish? ------------------------------------------------------------------------------
        getPgPID pgpid ## Here an exit status of 1 is the desired one
        case $? in
            0) ## Didn't finish, so previous attempt failed. Ask user to kill it manually
                if ! valpid "$pgpid"; then ## Invalid search result. Can't be sure about it, so request user to search
                    errmsg "Failed to confirm postgresql-${PGVERS} process stop."
                    stdmsg "Please, make sure manually."
                    return 5
                fi
                errmsg "Failed to stop process $pgpid. Try manually."
                return 6 ;;
            [^1]*) ## Unexpected error during process search. Can't be sure about it, so ask user to perform search
                errmsg "Failed to confirm postgresql-${PGVERS} process stop."
                stdmsg "Please, make sure manually."
                return 7 ;;
        esac
        ## Now we can be sure of process top
        printf "%s\n" "Postgresql-${PGVERS} stopped."
    }
    doStart() { #@ DESCRIPTION: Tries to start one single instance of PostgreSQL. It is simply a wrapper for the default
                #@              binary used by service's unit file w/the exact same options/artuments. Returns 2 or 1 on                          
                #@ USAGE: doStart    
        local pgpid
        ## Search for an already running PostgresSQL process -----------------------------------------------------------
        getPgPID pgpid ## Here an exit status of 1 is the desired one
        case $? in
            0) ## No, so previous attempt failed. Ask user to kill it manually
                if ! valpid "$pgpid"; then ## Invalid search result. Can't be sure about it, so request user to search
                    errmsg "Failed during postgresql-${PGVERS} process search."
                    stdmsg "Please search for running process manually, and try again."
                    return 1
                fi
                errmsg "Running postgresql-${PGVERS} process found on PID=${pgpid}"
                stdmsg "Stop it first and try again, or try restart instead."
                return 2 ;;
            [^1]*) ## Unexpected error during process search. Can't be sure about it, so ask user to perform search
                errmsg "Falure during postgresql-${PGVERS} process search."
                stdmsg "Please search for running process manually, and try again."
                return 3 ;;
        esac
        ## Now we can be sure that no process is running, so safe to start it ------------------------------------------
        stdmsg "Checking datadir $PGDATA files.." ## Check datadir files first
        sleep 2 2>/dev/null
        # First check $PGDATA file
        if ! $PGBIN/postgresql${PGVERS%.*}${PGVERS#*.}-check-db-dir "$PGDATA"; then
            errmsg "Datadir check failed."
            return 4
        fi
        stdmsg "Datadir files OK."\
               "Starting postgresql-${PGVERS} service.."
        sleep 2 2>/dev/null
        # Then try to start..
        if ! $PGBIN/pg_ctl start -D "$PGDATA" -s -w -t 300; then
            errmsg "Failed to start service."
            return 5
        fi
        sleep 2 2>/dev/null ## Allow some time for process to stop
        ## Did the process really start? -------------------------------------------------------------------------------
        getPgPID pgpid ## Here an exit status of 0 is the desired one
        case $? in
            1) ## No process found, so failed anyways... :-(
                errmsg "Failed to start service."
                return 6 ;;
            [^0]*) ## Unexpected error during process search. Can't be sure about it, so ask user to perform search
                errmsg "Failed during postgresql-${PGVERS} process search."
                stdmsg "Please, make sure process is running manually."
                return 7 ;;
            0)
                if ! valpid "$pgpid"; then ## Invalid search result. Can't be sure about it, so request user to search
                    errmsg "Failed during postgresql-${PGVERS} process search."
                    stdmsg "Please, make sure is running manually."
                    return 8
                fi ;;
        esac
        stdmsg "Postgresql-${PGVERS} started on PID=${pgpid}."
    }
    doReload() { #@ DESCRIPTION: Tries to reload configuration for currently running PostgreSQL instance. Wrapper for
                 #@              default binary used by service's unit file w/the same options/artuments. Returns 1 on
                 #@              failure and 0 on succes.
                 #@ USAGE: doReload
        stdmsg "Reloading postgresql-${PGVERS} configuration.."
        sleep 2 2>/dev/null
        if ! $PGBIN/pg_ctl reload -D "$PGDATA" -s; then
            stderr "Failed to reload configuration."
            return 1
        fi
        printf "%s\n" "Configuration reloaded."
    }
    doStatus() { #@ DESCRIPTION: Checks whether if an instance of postgreSQL is currently running
                 #@ USAGE: doStatus
        local pgpid
        stdmsg "Searching for running postgresql-${PGVERS} process.."
        sleep 2 2>/dev/null
        getPgPID pgpid
        case $? in
            0)
                if ! valpid "$pgpid"; then ## Invalid search result. Can't be sure about it, so request user to search
                    errmsg "Failed during process search."
                    stdmsg "Please search for the process manualy."
                    return 1
                fi
                stdmsg  "Postgresql-${PGVERS} is running on PID=${pgpid}."
                return 0 ;;
            1)
                stdmsg  "Postgresql-${PGVERS} is NOT running."
                return 0 ;;
            *)
                errmsg "Failed during process search."
                stdmsg "Please search for the process manualy."
                return 2 ;;
        esac
    }
    readonly getPgPID doStop doStart doReload doStatus
    export _PGPID getPgPID doStop doStart doReload doStatus
    ##
    ## -- MAIN ---------------------------------------------------------------------------------------------------------
    pg_service() { #@ DESCRIPTION: Main function providing control over service. Receives one action argument upon $1,
                   #@              and performs one of the following:
                   #@              * Start PostgreSQL service;
                   #@              * Stop PostgreSQL;
                   #@              * Reload configuration;
                   #@              * Check for a currently running instance of the service.
                   #@ USAGE: pg_service '[ start|stop|restart|reload|status ]'
        set -- "${1?"Usage: pg_service {start|stop|restart|reload|status}"}"
        case $1 in
            start) ## Normal start
                doStart ;;
            stop) ## Normal stop
                doStop ;;
            restart) ## Restart
                doStop ## First try to stop
                case $? in ## Unless no process running or successfuly stopped, do not try start
                    [^01]) return $? ;;
                esac
                ## Now it is safe to try to start
                doStart ;;
            reload) ## Normal reload
                doReload ;;
            status) ## Normal status check
                doStatus ;;
            *)
                stdmsg "Usage: pg_service {start|stop|restart|reload|status}"
                return 1 ;;
        esac
    }
    readonly pg_service
    export pg_service
else ## If requirements are not meet, remove globals and finish
    unset PGDATA PGVERS PGBIN
fi
##
# Provide Postgres archive log cleanup tool
## Check requirements, if one is missing do not load any function/variable:
## * There must be a terminal allocated for tools to be loaded to environment (only for interactive remote shells);
## * User mut be postgres (provide utilities only for that user);
## * A valid PostgreSQL installation must be present (check for $PGDATA, $PGBIN/*);
## * Also validate access to needed binaries
if [ -t 0 ] &&
   [ "$USER" = postgres ] &&
   type pgrep >/dev/null 2>&1 &&
   type sleep >/dev/null 2>&1 &&
   [ -d "$PGDATA" -a -r "$PGDATA" -a -x "$PGDATA" ] &&
   type file >/dev/null &&
   type fuser >/dev/null &&
   type gzip >/dev/null &&
   type ps >/dev/null &&
   type rm >/dev/null &&
   type tee >/dev/null
then
    zparch() { #@ DESCRIPTION: Zips all postgres archive files within $1 directory, printing actions to $2 logfile.
               #@ USAGE: zparch [ PGARCHIVEDIR [ LOGPATH ] ]
        # Local variables (If local is used, it should appear as the first statement of a function)
        local pidf jbc pfmt path tpe pids ignrd lgs zppd kpt totl errs
        # Startup
        set -- "${1:-$PGDATA/archive}" "${2:-/tmp/zparch.log}" ## Set default vaules for arguments
        pidf=/tmp/zparch.pid                                   ## Set defalt path for pidfile
        if [ -e "$pidf" ]; then                                ## Check for previous currently running instance
            printf "%s\n" "Error! Another instance of zparch is already running" >&2
            return 2                                           ## Finish if previous instance is found
        fi
        if ! printf "%d\n" $$ >"$pidf"; then                    ## Send current pid to pidfile, creating it
            printf "%s\n" "Error! Failed to create pidfile" >&2 ## Or else finish w/errors
            return 2
        fi
        # Group actions to call at 2 exit points of workflow: Trap and normal exit
        finish() {
            # Set print format for summary
            pfmt="                    \nSummary                    \n------------------\n"
            pfmt="$pfmt%8s: %-10d\n%8s: %-10d\n%8s: %-10d\n%8s: %-10d\n%8s: %-10d\n%8s: %-10d\n\n"
            # Print summary
            printf "$pfmt"\
                   Nonlogs $nolgs logs $lgs Zipped $zppd\
                   Kept $kpt Total $totl Errors $errs | tee -a "${1:-/dev/null}"
            # Do the clean-up
            exec 3>&-                                                ## Close file descriptor
            $jbc && set -m                                           ## Switch job control state back
            rm -f "$pidf"                                            ## Remove pidfile
            [ -e "$pidf" ] && printf "%s\n" "Failed to remove $pidf" ## Check removal
            unset -f finish                                          ## Don't allow finish() outside zparch()
        }
        # Start listening to signals, finishing on Ctrl+C, kill -15 and -9
        trap 'printf "    %s\n" "Stopped by signal"; finish '"$2"'; return 3' INT TERM KILL
        # Turn off job control if enabled. This is needed to avoid annoying "Started" and "Done" terminal messages
        case $- in                   ## If current shell options..
            *m*) set +m; jbc=true ;; ## Include "-m" for job control, disable it and remember action w/flag
            *) jbc=false ;;          ## Else set flag to false
        esac
        # Initalize locals
        pfmt="%8s: %-10d\n%8s: %-10d\n%8s: %-10d\n%8s: %-10d\n%8s: %-10d\033[4A\033[20D" ## Printf format for the loop
        nolgs=0 lgs=0 zppd=0 kpt=0 totl=0 errs=0                                         ## Counters, zipped, kept, etc
        # Additional initializations
        if ! ( exec 3>"$2" ); then                                ## Test if possible to open logile in background
            printf "%s\n" "Error! Failed to open logfile $2" >&2  ## If not possible, finish w/errors.
            finish                                                ## Due to posix restrictions on "exec" if exec fails
            return 3                                              ## it's impossible to prevent script exit, hence
        fi                                                        ## we check first, and then try to open. however this
        exec 3>"$2"                                               ## this is sitll unsafe.
        { sleep 2 & } 2>/dev/null                                 ## Start background dummy to later check elapsed time
        # Main loop, for each read reply (path to archive file)..
        while IFS= read -r path; do         ## Use empty IFS to avoid word splitting on lines
            if tpe=$(file -i "$path"); then ## If cannot retrieve file type, skip file
                case $tpe in                    ## Check on retreived mime type
                    *application/octet-stream*) ## If not as expected (postgres archive file), skip file
                        if pids=$(fuser -f "$path" 2>&1); then ## If got pids of procs using file..
                            kpt=$((kpt + 1))                   ## * File will be left alone, so increase kept counter
                        elif [ "X$pids" != X ]; then           ## If failed to get pids, and found fuser errors
                            printf "%s\n" "Error! In-use test file failed for $path" >&3 ## * Print an error message
                            errs=$((errs + 1))                                           ## * Increase errors count
                            kpt=$((kpt + 1))                                             ## * Keep file, so count it
                        else                    ## If failed to get pids w/no fuser erros, assume file is not being used
                            printf "%s" "Zipping " >&3                   ## So, process unused archive file
                            if ! gzip -v "$path" >&3 2>&1; then          ## Try to zip file, if fail
                                printf "%s\n" "Error! Failed to zip" >&3 ## * Print an error message
                                errs=$((errs + 1))                       ## * Increase errors count
                                kpt=$((kpt + 1))                         ## * Keep file, so count it
                            elif ! rm -vf "$path" >&3 2>&1; then            ## If zipped, try to remove original if avail
                                printf "%s\n" "Error! Failed to remove" >&3 ## Print an error on removal failure
                                rm -vf "$path".gz >&3 2>&1                  ## As original archive is kept, remove zipped
                                errs=$((errs + 1))                          ## Increase errors count
                                kpt=$((kpt + 1))                            ## Also kpet files count
                            else                   ## Now that we are sure that archive was zipped and removed,
                                zppd=$((zppd + 1)) ## Increase the zipped count
                            fi
                        fi                         ## We are sure that current path ponts to archive file
                        lgs=$((lgs + 1)) ;;        ## increase archive logs counter
                    *)                          ## Current path do not point to archive file so
                        nolgs=$((nolgs + 1)) ;; ## inrease the nonlogs counter
                esac
            else                                                    ## If failed to retrieve file type
                printf "%s\n" "Error! Failed to get file type" >&3  ## Print an error messae
                errs=$((errs + 1))                                  ## Take this as an error
                kpt=$((kpt + 1))                                    ## File is skipped, hence kept
            fi
            totl=$((totl + 1))                                        ## Increase total files counter
            if ! ps -o pid -p $! >/dev/null 2>/dev/null; then         ## Refresh stdout only if background dummie died
                printf "$pfmt" Nonlogs $nolgs logs $lgs Zipped $zppd\
                       Kept $kpt Errors $errs
                { sleep 2 & } 2>/dev/null                             ## Start new background dummie for next loop
            fi
        done <<EOF
$(printf "%s\n" "$1"/*)
EOF
# Get list of $1 contained files using pathname espansion
# Fetch list to a here document to be read by the while loop
        # Finish execution propperly
        finish "$2"                  ## Use $2 log file to output summary
        [ $errs -eq 0 ] || return 1  ## If there were some errors, let the calling environment know
    }
fi

#: Title       : Pgprofile.sh
#: Date        : 2017-08-24
#: Author      : "Kybernetes" <correodelkybernetes@gmail.com>
#: Version     : 1.0.0
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
                return 0;;
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

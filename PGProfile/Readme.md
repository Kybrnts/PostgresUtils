#: Title       : Readme.md
#: Date        : 2017-08-24
#: Author      : "Kybernetes" <correodelkybernetes@gmail.com>
#: Version     : 1.0.0
#: Description : Text file
#:             : Contains Pgprofile script specs
#:             : 
#: Options     : N/A
#: Copyright   : To the extent possible under law, the author(s) have dedicated all copyright and related and
#:             : neighboring rights to this software to the  public domain worldwide. This software is distributed
#:             : without any warranty. You should have received a copy of the CC0 Public Domain Dedication along with
#:             : this software. If not, please visit http://creativecommons.org/publicdomain/zero/1.0/.
##
## -- Abstract ---------------------------------------------------------------------------------------------------------
The objective is to provide a tool for Database administrators that easely starts, stops and reloads configuration of
the PostgreSQL service. It shall restrict this control to the postgres system user only, and in a PostgreSQL version
agnostic way (i.e. ideally it will work with any version of the product).
##
## -- Requirements -----------------------------------------------------------------------------------------------------
* Allow to perform the four basic operations any SystemV init script would: start, stop, reload, restart.
* Restrict acces to this operations:
  * Only for interactive postgres sessions
  * PostgreSQL must be installed
##
## -- Workflow ---------------------------------------------------------------------------------------------------------

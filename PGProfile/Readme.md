Abstract
--------
The objective is to provide a tool for Database administrators that easely starts, stops and reloads configuration of
the PostgreSQL service. It shall restrict this control to the postgres system user only, and in a PostgreSQL version
agnostic way (i.e. ideally it will work with any version of the product).

Requirements
------------
* Allow to perform the four basic operations any SystemV init script would: start, stop, reload, restart.
* Restrict acces to this operations:
  * Only for interactive postgres sessions
  * PostgreSQL must be installed

Workflow
--------
This section has nothing yet

Installation
------------
This section has nothing yet

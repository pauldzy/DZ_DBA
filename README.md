DZ_DBA

PL/SQL code for the summation and reorganization of database objects

This module was created for the purpose of carefully moving about resources from datafile to datafile as the existing OEM tools do not support online movement of tables having domain (e.g. spatial) indexes.  Of course as always just dumping the data via datapump and reimporting is much easier but in this scenario is not an option.

Thus the move function in the main package may be of limited utility in 2015.  Use as you will.  The functions in the DZ_DBA_SIZER may still be of interest as they allow one to exactly summarize the space in the database used by tables, lob and indexes (including domain indexes).

Any feedback or improvements are appreciated.

CREATE OR REPLACE TYPE dz_dba_summary_list FORCE
AS 
TABLE OF dz_dba_summary;
/

GRANT EXECUTE ON dz_dba_summary_list TO PUBLIC;


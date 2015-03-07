CREATE OR REPLACE PACKAGE dz_dba_util
AUTHID CURRENT_USER
AS
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   -- Note: Utility functions may be duplicated across several DZ modules
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gz_split(
       p_str              IN VARCHAR2
      ,p_regex            IN VARCHAR2
      ,p_match            IN VARCHAR2 DEFAULT NULL
      ,p_end              IN NUMBER   DEFAULT 0
      ,p_trim             IN VARCHAR2 DEFAULT 'FALSE'
   ) RETURN MDSYS.SDO_STRING2_ARRAY DETERMINISTIC;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION table_exists(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_table_name       IN  VARCHAR2
      ,p_column_name      IN  VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2;

END dz_dba_util;
/

GRANT EXECUTE ON dz_dba_util TO PUBLIC;

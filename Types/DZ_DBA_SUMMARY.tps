CREATE OR REPLACE TYPE dz_dba_summary FORCE
AUTHID CURRENT_USER
AS OBJECT (
    owner                    VARCHAR2(30 Char)
   ,table_name               VARCHAR2(30 Char)
   ,category_type1           VARCHAR2(255 Char)
   ,category_type2           VARCHAR2(255 Char)
   ,category_type3           VARCHAR2(255 Char)
   ,parent_owner             VARCHAR2(30 Char)
   ,parent_table_name        VARCHAR2(30 Char)
   ,item_size_bytes          NUMBER
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   ,CONSTRUCTOR FUNCTION dz_dba_summary
    RETURN SELF AS RESULT

);
/

GRANT EXECUTE ON dz_dba_summary TO PUBLIC;


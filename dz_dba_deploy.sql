
--*************************--
PROMPT sqlplus_header.sql;

WHENEVER SQLERROR EXIT -99;
WHENEVER OSERROR  EXIT -98;
SET DEFINE OFF;



--*************************--
PROMPT DZ_DBA_SUMMARY.tps;

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


--*************************--
PROMPT DZ_DBA_SUMMARY.tpb;

CREATE OR REPLACE TYPE BODY dz_dba_summary
AS

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   CONSTRUCTOR FUNCTION dz_dba_summary
   RETURN SELF AS RESULT
   AS
   BEGIN
      RETURN;
      
   END dz_dba_summary;

END;
/


--*************************--
PROMPT DZ_DBA_SUMMARY_LIST.tps;

CREATE OR REPLACE TYPE dz_dba_summary_list FORCE
AS 
TABLE OF dz_dba_summary;
/

GRANT EXECUTE ON dz_dba_summary_list TO PUBLIC;


--*************************--
PROMPT DZ_DBA_UTIL.pks;

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


--*************************--
PROMPT DZ_DBA_UTIL.pkb;

CREATE OR REPLACE PACKAGE BODY dz_dba_util
AS

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gz_split(
       p_str              IN VARCHAR2
      ,p_regex            IN VARCHAR2
      ,p_match            IN VARCHAR2 DEFAULT NULL
      ,p_end              IN NUMBER   DEFAULT 0
      ,p_trim             IN VARCHAR2 DEFAULT 'FALSE'
   ) RETURN MDSYS.SDO_STRING2_ARRAY DETERMINISTIC 
   AS
      int_delim      PLS_INTEGER;
      int_position   PLS_INTEGER := 1;
      int_counter    PLS_INTEGER := 1;
      ary_output     MDSYS.SDO_STRING2_ARRAY;
      num_end        NUMBER      := p_end;
      str_trim       VARCHAR2(5 Char) := UPPER(p_trim);
      
      FUNCTION trim_varray(
         p_input            IN MDSYS.SDO_STRING2_ARRAY
      ) RETURN MDSYS.SDO_STRING2_ARRAY
      AS
         ary_output MDSYS.SDO_STRING2_ARRAY := MDSYS.SDO_STRING2_ARRAY();
         int_index  PLS_INTEGER := 1;
         str_check  VARCHAR2(4000 Char);
         
      BEGIN

         --------------------------------------------------------------------------
         -- Step 10
         -- Exit if input is empty
         --------------------------------------------------------------------------
         IF p_input IS NULL
         OR p_input.COUNT = 0
         THEN
            RETURN ary_output;
            
         END IF;

         --------------------------------------------------------------------------
         -- Step 20
         -- Trim the strings removing anything utterly trimmed away
         --------------------------------------------------------------------------
         FOR i IN 1 .. p_input.COUNT
         LOOP
            str_check := TRIM(p_input(i));
            IF str_check IS NULL
            OR str_check = ''
            THEN
               NULL;
               
            ELSE
               ary_output.EXTEND(1);
               ary_output(int_index) := str_check;
               int_index := int_index + 1;
               
            END IF;

         END LOOP;

         --------------------------------------------------------------------------
         -- Step 10
         -- Return the results
         --------------------------------------------------------------------------
         RETURN ary_output;

      END trim_varray;

   BEGIN

      --------------------------------------------------------------------------
      -- Step 10
      -- Create the output array and check parameters
      --------------------------------------------------------------------------
      ary_output := MDSYS.SDO_STRING2_ARRAY();

      IF str_trim IS NULL
      THEN
         str_trim := 'FALSE';
         
      ELSIF str_trim NOT IN ('TRUE','FALSE')
      THEN
         RAISE_APPLICATION_ERROR(-20001,'boolean error');
         
      END IF;

      IF num_end IS NULL
      THEN
         num_end := 0;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 20
      -- Exit early if input is empty
      --------------------------------------------------------------------------
      IF p_str IS NULL
      OR p_str = ''
      THEN
         RETURN ary_output;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 30
      -- Account for weird instance of pure character breaking
      --------------------------------------------------------------------------
      IF p_regex IS NULL
      OR p_regex = ''
      THEN
         FOR i IN 1 .. LENGTH(p_str)
         LOOP
            ary_output.EXTEND(1);
            ary_output(i) := SUBSTR(p_str,i,1);
            
         END LOOP;
         
         RETURN ary_output;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 40
      -- Break string using the usual REGEXP functions
      --------------------------------------------------------------------------
      LOOP
         EXIT WHEN int_position = 0;
         int_delim  := REGEXP_INSTR(p_str,p_regex,int_position,1,0,p_match);
         
         IF  int_delim = 0
         THEN
            -- no more matches found
            ary_output.EXTEND(1);
            ary_output(int_counter) := SUBSTR(p_str,int_position);
            int_position  := 0;
            
         ELSE
            IF int_counter = num_end
            THEN
               -- take the rest as is
               ary_output.EXTEND(1);
               ary_output(int_counter) := SUBSTR(p_str,int_position);
               int_position  := 0;
               
            ELSE
               --dbms_output.put_line(ary_output.COUNT);
               ary_output.EXTEND(1);
               ary_output(int_counter) := SUBSTR(p_str,int_position,int_delim-int_position);
               int_counter := int_counter + 1;
               int_position := REGEXP_INSTR(p_str,p_regex,int_position,1,1,p_match);
               
            END IF;
            
         END IF;
         
      END LOOP;

      --------------------------------------------------------------------------
      -- Step 50
      -- Trim results if so desired
      --------------------------------------------------------------------------
      IF str_trim = 'TRUE'
      THEN
         RETURN trim_varray(
            p_input => ary_output
         );
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 60
      -- Cough out the results
      --------------------------------------------------------------------------
      RETURN ary_output;
      
   END gz_split;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION table_exists(
       p_owner            IN  VARCHAR2 DEFAULT NULL
      ,p_table_name       IN  VARCHAR2
      ,p_column_name      IN  VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2
   AS
      str_owner        VARCHAR2(30 Char) := UPPER(p_owner);
      num_tab          PLS_INTEGER;
      
   BEGIN

      IF str_owner IS NULL
      THEN
         str_owner := USER;
         
      END IF;

      IF p_column_name IS NULL
      THEN
         SELECT 
         COUNT(*) 
         INTO num_tab
         FROM (
            SELECT 
             aa.owner
            ,aa.table_name 
            FROM 
            all_all_tables aa
            UNION ALL 
            SELECT 
             bb.owner
            ,bb.view_name AS table_name
            FROM 
            all_views bb
         ) a 
         WHERE 
             a.owner      = str_owner
         AND a.table_name = p_table_name;

      ELSE
         SELECT 
         COUNT(*) 
         INTO num_tab
         FROM (
            SELECT 
             aa.owner
            ,aa.table_name 
            FROM 
            all_all_tables aa
            UNION ALL 
            SELECT 
             bb.owner
            ,bb.view_name AS table_name
            FROM 
            all_views bb
         ) a 
         JOIN 
         all_tab_cols b 
         ON 
             a.owner = b.owner
         AND a.table_name = b.table_name 
         WHERE 
             a.owner = str_owner
         AND a.table_name = p_table_name
         AND b.column_name = p_column_name;

      END IF;

      IF num_tab = 0
      THEN
         RETURN 'FALSE';
         
      ELSE
         RETURN 'TRUE';
         
      END IF;

   END table_exists;
   
END dz_dba_util;
/


--*************************--
PROMPT DZ_DBA_MAIN.pks;

CREATE OR REPLACE PACKAGE dz_dba_main 
AUTHID CURRENT_USER
AS
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   header: DZ_DBA
     
   - Build ID: 11
   - TFS Change Set: 8194
   
   Utilities for the summation and reorganization of resource storage in Oracle.
   
   Access to dba_extents, dba_data_files and dba_tablespaces is required in 
   order to read resource information.
   
   */
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   
   TYPE rec_action_list IS RECORD(
       p_owner          VARCHAR2(30 Char)
      ,p_segment_name   VARCHAR2(30 Char)
      ,p_segment_type   VARCHAR2(30 Char)
      ,p_block_id       NUMBER
      ,p_tablespace     VARCHAR2(30 Char)
      ,p_statement      VARCHAR2(2000 Char)
      ,p_swap_statement VARCHAR2(2000 Char)
      ,p_swap_segment   VARCHAR2(2000 Char)
   );

   TYPE tbl_action_list IS TABLE OF rec_action_list;
   
   TYPE quick_pipe IS TABLE OF VARCHAR2(2000 Char);
   
   TYPE number_hash IS TABLE OF NUMBER
   INDEX BY VARCHAR2(4000 Char);
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION create_hw_pack_statement_pipe(
       p_datafile     IN  VARCHAR2
      ,p_swap_ts      IN  VARCHAR2 DEFAULT NULL
   ) RETURN tbl_action_list PIPELINED;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_dba_main.move_it
   
   Function to return the DDL to move a given segment into another tablespace.

   Parameters:

      p_owner        - owner of the segment (default USER)
      p_segment_name - segment to move
      p_tablespace   - destination tablespace (optional)

   Returns:

      VARCHAR2
   
   */
   FUNCTION move_it(
       p_owner        IN  VARCHAR2
      ,p_segment_name IN  VARCHAR2
      ,p_tablespace   IN  VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_dba_main.move_it_pipe
   
   Function to return the DDL to move a given segment into another tablespace.

   Parameters:

      p_owner        - owner of the segment (default USER)
      p_segment_name - segment to move
      p_tablespace   - destination tablespace (optional)

   Returns:

      Pipelined table of VARCHAR2
   
   */
   FUNCTION move_it_pipe(
       p_owner        IN  VARCHAR2
      ,p_segment_name IN  VARCHAR2
      ,p_tablespace   IN  VARCHAR2 DEFAULT NULL
   ) RETURN quick_pipe PIPELINED;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_dba_main.move_end
   
   Function to return the DDL to move the item at the highwater mark of the  
   datafile into another tablespace.

   Parameters:

      p_datafile     - datafile with highwater item to move
      p_tablespace   - destination tablespace (optional)

   Returns:

      VARCHAR2
   
   */
   FUNCTION move_end(
       p_datafile     IN  VARCHAR2
      ,p_tablespace   IN  VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_dba_main.move_end_pipe
   
   Function to return the DDL to move the item at the highwater mark of the  
   datafile into another tablespace.

   Parameters:

      p_datafile     - datafile with highwater item to move
      p_tablespace   - destination tablespace (optional)

   Returns:

      Pipelined table of VARCHAR2
   
   */
   FUNCTION move_end_pipe(
       p_datafile     IN  VARCHAR2
      ,p_tablespace   IN  VARCHAR2 DEFAULT NULL
   ) RETURN quick_pipe PIPELINED;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_dba_main.move_all_pipe
   
   Function to return all the DDL to move all of the items in a datafile into   
   another tablespace ordered from the highwater mark descending.

   Parameters:

      p_datafile     - datafile with items to move
      p_tablespace   - destination tablespace (optional)

   Returns:

      Pipelined table of VARCHAR2
   
   */
   FUNCTION move_all_pipe(
       p_datafile     IN  VARCHAR2
      ,p_tablespace   IN  VARCHAR2 DEFAULT NULL
   ) RETURN quick_pipe PIPELINED;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION find_voids_pipe(
       p_datafile     IN  VARCHAR2
      ,p_size_minimum IN  NUMBER DEFAULT 2147483648
      ,p_tablespace   IN  VARCHAR2 DEFAULT NULL
   ) RETURN quick_pipe PIPELINED;
   
END dz_dba_main;
/

GRANT EXECUTE ON dz_dba_main TO public;


--*************************--
PROMPT DZ_DBA_MAIN.pkb;

CREATE OR REPLACE PACKAGE BODY dz_dba_main
AS

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION has_row_movement(
       p_owner        IN  VARCHAR2
      ,p_table_name   IN  VARCHAR2
   ) RETURN VARCHAR2
   AS
      str_out VARCHAR2(4000 Char);
      
   BEGIN
   
      SELECT
      a.row_movement
      INTO str_out
      FROM (
         SELECT
          b.owner
         ,b.table_name
         ,b.row_movement
         FROM
         all_tables b
         UNION SELECT
          c.owner
         ,c.table_name
         ,c.row_movement
         FROM
         all_object_tables c
      ) a
      WHERE
          a.owner = p_owner
      AND a.table_name = p_table_name;
      
      RETURN str_out;
              
   EXCEPTION
      WHEN OTHERS
      THEN
         RAISE;
                  
   END has_row_movement;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------   
   PROCEDURE check_index_is_IOT(
       p_owner        IN  VARCHAR2
      ,p_index_name   IN  VARCHAR2
      ,p_table_owner  OUT VARCHAR2
      ,p_table_name   OUT VARCHAR2
   ) 
   AS
   BEGIN
  
      SELECT
       a.table_owner
      ,a.table_name
      INTO 
       p_table_owner
      ,p_table_name 
      FROM
      all_indexes a
      WHERE
          a.index_type = 'IOT - TOP'
      AND a.owner = p_owner
      AND a.index_name = p_index_name;    
         
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         --dbms_output.put_line(str_sql);
         --dbms_output.put_line(p_owner);
         --dbms_output.put_line(p_index_name);
         p_table_owner := NULL;
         p_table_name  := NULL;
            
      WHEN OTHERS
      THEN
         RAISE;

   END check_index_is_IOT;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------   
   PROCEDURE get_lob_table(
       p_owner        IN  VARCHAR2
      ,p_segment_name IN  VARCHAR2
      ,p_table_owner  OUT VARCHAR2
      ,p_table_name   OUT VARCHAR2
      ,p_column_name  OUT VARCHAR2
      ,p_tablespace   OUT VARCHAR2
      ,p_column_type  OUT VARCHAR2
   ) 
   AS
      ary_split       MDSYS.SDO_STRING2_ARRAY;
      
   BEGIN
   
      SELECT
       a.owner
      ,a.table_name
      ,a.column_name
      ,a.tablespace_name
      ,b.data_type
      INTO 
       p_table_owner
      ,p_table_name
      ,p_column_name
      ,p_tablespace
      ,p_column_type
      FROM
      all_lobs a
      LEFT JOIN
      all_tab_columns b
      ON
          a.owner = b.owner
      AND a.table_name = b.table_name
      AND a.column_name = b.column_name
      WHERE
          a.owner = p_owner
      AND (
         a.segment_name = p_segment_name OR a.index_name = p_segment_name
      );
      
      ary_split := dz_dba_util.gz_split(
         p_str   => p_column_name,
         p_regex => '\.'
      );
      
      IF  ary_split.COUNT = 2
      AND ary_split(2) IN ('"SDO_ORDINATES"','"SDO_ELEM_INFO"')
      THEN
         p_column_type := 'SDO_GEOMETRY';
         
      END IF;
      
   EXCEPTION
      WHEN OTHERS
      THEN
         RAISE;
             
   END get_lob_table;
   
   -----------------------------------------------------------------------------
   ----------------------------------------------------------------------------- 
   PROCEDURE get_hw_segment(
       p_datafile     IN  VARCHAR2
      ,p_owner        OUT VARCHAR2
      ,p_segment_name OUT VARCHAR2
      ,p_segment_type OUT VARCHAR2
      ,p_block_id     OUT NUMBER
      ,p_tablespace   OUT VARCHAR2
   )
   AS
      str_sql VARCHAR2(4000 Char);
      
   BEGIN
   
      str_sql := 'SELECT '
              || '* '
              || 'FROM ('
              || '   SELECT '
              || '    a.owner '
              || '   ,a.segment_name '
              || '   ,a.segment_type '
              || '   ,a.block_id '
              || '   ,a.tablespace_name '
              || '   FROM '
              || '   dba_extents a '
              || '   WHERE '
              || '   a.file_id = ( '
              || '      SELECT '
              || '      b.file_id '
              || '      FROM '
              || '      dba_data_files b '
              || '      WHERE '
              || '      b.file_name = :p1 '
              || '   ) '
              || '   ORDER BY '
              || '   a.block_id DESC '
              || ') '
              || 'WHERE '
              || 'rownum <= 1 ';
              
      EXECUTE IMMEDIATE str_sql 
      INTO 
       p_owner
      ,p_segment_name
      ,p_segment_type
      ,p_block_id
      ,p_tablespace 
      USING p_datafile; 
      
   END get_hw_segment;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE get_segment(
       p_owner        IN  VARCHAR2
      ,p_segment_name IN  VARCHAR2
      ,p_segment_type OUT VARCHAR2
      ,p_block_id     OUT NUMBER
      ,p_tablespace   OUT VARCHAR2
   )
   AS
      str_sql          VARCHAR2(4000 Char);
      
   BEGIN
   
      str_sql := 'SELECT '
              || ' a.segment_type '
              || ',a.block_id '
              || ',a.tablespace_name '
              || 'FROM '
              || 'dba_extents a '
              || 'WHERE '
              || '    a.owner = UPPER(:p01) '
              || 'AND a.segment_name = UPPER(:p02) '
              || 'AND rownum <= 1 ';
            
      BEGIN        
         EXECUTE IMMEDIATE str_sql 
         INTO 
          p_segment_type
         ,p_block_id
         ,p_tablespace
         USING 
          p_owner
         ,p_segment_name;
           
      EXCEPTION
         WHEN OTHERS
         THEN
            RAISE;
            
      END;

   END get_segment;
   
   -----------------------------------------------------------------------------
   ----------------------------------------------------------------------------- 
   PROCEDURE pack_statement(
       p_owner          IN  VARCHAR2
      ,p_segment_name   IN  VARCHAR2
      ,p_segment_type   IN  VARCHAR2 DEFAULT NULL
      ,p_block_id       IN  NUMBER   DEFAULT NULL
      ,p_tablespace     IN  VARCHAR2 DEFAULT NULL
      ,p_swap_ts        IN  VARCHAR2 DEFAULT NULL
      ,p_statement      OUT VARCHAR2
      ,p_swap_statement OUT VARCHAR2
      ,p_statement_obj  OUT VARCHAR2
   )
   AS
   
      str_segment_type   VARCHAR2(256 Char);
      num_block_id       NUMBER;
      str_tablespace     VARCHAR2(30 Char);
      str_iot_owner      VARCHAR2(30 Char);
      str_iot_table      VARCHAR2(30 Char);
      str_lob_owner      VARCHAR2(30 Char);
      str_lob_table      VARCHAR2(30 Char);
      str_lob_column     VARCHAR2(256 Char);
      str_lob_tablespace VARCHAR2(30 Char);
      str_column_type    VARCHAR2(256 Char);
      
   BEGIN
   
      IF p_segment_type IS NULL
      OR p_block_id IS NULL
      THEN
         get_segment(
             p_owner        => p_owner
            ,p_segment_name => p_segment_name
            ,p_segment_type => str_segment_type
            ,p_block_id     => num_block_id
            ,p_tablespace   => str_tablespace
         );
         
      ELSE
         str_segment_type := UPPER(p_segment_type);
         num_block_id     := p_block_id;
         str_tablespace   := p_tablespace;
         
      END IF;
      
      IF str_segment_type = 'TABLE'
      THEN
         IF has_row_movement(
             p_owner      => p_owner
            ,p_table_name => p_segment_name
         ) = 'DISABLED'
         THEN
            p_statement := 'ALTER TABLE ' || p_owner || '.' || p_segment_name || ' SHRINK SPACE CASCADE; '
                        || 'ALTER TABLE ' || p_owner || '.' || p_segment_name || ' MOVE; '; 
                        
         ELSE
            p_statement := 'ALTER TABLE ' || p_owner || '.' || p_segment_name || ' SHRINK SPACE CASCADE; '
                        || 'ALTER TABLE ' || p_owner || '.' || p_segment_name || ' MOVE; ';
                        
         END IF;
         
         p_swap_statement := 'ALTER TABLE ' || p_owner || '.' || p_segment_name || ' MOVE TABLESPACE ' || p_swap_ts || '; ';
         p_statement_obj := p_segment_name;  
                
      ELSIF str_segment_type = 'INDEX'
      THEN
         check_index_is_IOT(
             p_owner        => p_owner
            ,p_index_name   => p_segment_name
            ,p_table_owner  => str_iot_owner
            ,p_table_name   => str_iot_table
         );
         
         IF str_iot_table IS NULL
         THEN
            p_statement := 'ALTER INDEX ' || p_owner || '.' || p_segment_name || ' SHRINK SPACE; '
                        || 'ALTER INDEX ' || p_owner || '.' || p_segment_name || ' REBUILD;';
            p_swap_statement := 'ALTER INDEX ' || p_owner || '.' || p_segment_name || ' REBUILD TABLESPACE ' || p_swap_ts || '; ';
            p_statement_obj := p_segment_name; 
            
         ELSE
            p_statement := 'ALTER TABLE ' || str_iot_owner || '.' || str_iot_table || ' SHRINK SPACE CASCADE; '
                        || 'ALTER TABLE ' || str_iot_owner || '.' || str_iot_table || ' MOVE; ';
            p_swap_statement := 'ALTER TABLE ' || str_iot_owner || '.' || str_iot_table || ' MOVE TABLESPACE ' || p_swap_ts || '; ';
            p_statement_obj := str_iot_table; 
            
         END IF;
         
      ELSIF str_segment_type = 'LOBSEGMENT' OR str_segment_type = 'LOBINDEX'
      THEN
         get_lob_table(
             p_owner        => p_owner
            ,p_segment_name => p_segment_name
            ,p_table_owner  => str_lob_owner
            ,p_table_name   => str_lob_table
            ,p_column_name  => str_lob_column
            ,p_tablespace   => str_lob_tablespace
            ,p_column_type  => str_column_type
         );

         IF str_lob_table IS NULL
         THEN
            RAISE_APPLICATION_ERROR(
                -20001
               ,'ERROR with ' || p_segment_name
            );
            
         ELSE
            IF str_column_type IN ('GENSTRINGSEQUENCE','SDO_GEOMETRY')
            THEN
               IF has_row_movement(
                   p_owner      => str_lob_owner
                  ,p_table_name => str_lob_table
               ) = 'DISABLED'
               THEN
                  p_statement := 'ALTER TABLE ' || str_lob_owner || '.' || str_lob_table || ' SHRINK SPACE CASCADE; '
                              || 'ALTER TABLE ' || str_lob_owner || '.' || str_lob_table || ' MOVE; ';
                              
               ELSE
                  p_statement := 'ALTER TABLE ' || str_lob_owner || '.' || str_lob_table || ' SHRINK SPACE CASCADE; '
                              || 'ALTER TABLE ' || str_lob_owner || '.' || str_lob_table || ' MOVE; ';
                              
               END IF;
               
               p_swap_statement := 'ALTER TABLE ' || str_lob_owner || '.' || str_lob_table || ' MOVE TABLESPACE ' || p_swap_ts || '; '; 
               
            ELSE
               IF has_row_movement(
                   p_owner      => str_lob_owner
                  ,p_table_name => str_lob_table
               ) = 'DISABLED'
               THEN
                  p_statement := 'ALTER TABLE ' || str_lob_owner || '.' || str_lob_table || ' SHRINK SPACE CASCADE; '
                              || 'ALTER TABLE ' || str_lob_owner || '.' || str_lob_table || ' MOVE LOB (' || str_lob_column || ') STORE AS (TABLESPACE ' || str_tablespace || '); ';
               
               ELSE
                  p_statement := 'ALTER TABLE ' || str_lob_owner || '.' || str_lob_table || ' SHRINK SPACE CASCADE; '
                              || 'ALTER TABLE ' || str_lob_owner || '.' || str_lob_table || ' MOVE LOB (' || str_lob_column || ') STORE AS (TABLESPACE ' || str_tablespace || '); ';
               
               END IF;
               
               p_swap_statement := 'ALTER TABLE ' || str_lob_owner || '.' || str_lob_table || ' MOVE LOB (' || str_lob_column || ') STORE AS (TABLESPACE ' || p_swap_ts || '); ';
            
            END IF;
            
            p_statement_obj := str_lob_table; 
         
         END IF;
      
      ELSE
         RAISE_APPLICATION_ERROR(
             -20001
            ,'dunno how to handle ' || str_segment_type
         );
         
      END IF;
   
   END pack_statement;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------   
   FUNCTION create_pack_statement(
       p_owner        IN  VARCHAR2
      ,p_segment_name IN  VARCHAR2
      ,p_segment_type IN  VARCHAR2 DEFAULT NULL
      ,p_block_id     IN  NUMBER   DEFAULT NULL
      ,p_tablespace   IN  VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2
   AS
      str_swap_ts        VARCHAR2(30 Char);
      str_statement      VARCHAR2(2000 Char);
      str_swap_statement VARCHAR2(2000 Char);
      str_swap_object    VARCHAR2(30 Char);
      
   BEGIN   
   
      pack_statement(
          p_owner          => p_owner
         ,p_segment_name   => p_segment_name
         ,p_segment_type   => p_segment_type
         ,p_block_id       => p_block_id
         ,p_tablespace     => p_tablespace
         ,p_swap_ts        => str_swap_ts
         ,p_statement      => str_statement
         ,p_swap_statement => str_swap_statement
         ,p_statement_obj  => str_swap_object
      );
      
      RETURN str_statement;
   
   END create_pack_statement;
   
   -----------------------------------------------------------------------------
   ----------------------------------------------------------------------------- 
   FUNCTION create_hw_pack_statement(
       p_datafile        IN  VARCHAR2
      ,p_swap_tablespace IN  VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2
   AS
      str_owner        VARCHAR2(30 Char);
      str_segment_name VARCHAR2(256 Char);
      str_segment_type VARCHAR2(256 Char);
      num_block_id     NUMBER;
      str_tablespace   VARCHAR2(30 Char);
      
   BEGIN
      
      get_hw_segment(
          p_datafile     => p_datafile
         ,p_owner        => str_owner
         ,p_segment_name => str_segment_name
         ,p_segment_type => str_segment_type
         ,p_block_id     => num_block_id
         ,p_tablespace   => str_tablespace
      );
      
      RETURN create_pack_statement(
          p_owner        => str_owner
         ,p_segment_name => str_segment_name
         ,p_segment_type => str_segment_type
         ,p_block_id     => num_block_id
         ,p_tablespace   => str_tablespace
      );
   
   END create_hw_pack_statement;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------   
   FUNCTION create_hw_pack_statement_pipe(
       p_datafile     IN  VARCHAR2
      ,p_swap_ts      IN  VARCHAR2 DEFAULT NULL
   ) RETURN tbl_action_list PIPELINED
   AS
      str_owner        VARCHAR2(30 Char);
      str_segment_name VARCHAR2(256 Char);
      str_segment_type VARCHAR2(256 Char);
      str_tablespace   VARCHAR2(30 Char);
      num_block_id     NUMBER;
      rec_output       rec_action_list;
      
   BEGIN
   
      get_hw_segment(
          p_datafile     => p_datafile
         ,p_owner        => str_owner
         ,p_segment_name => str_segment_name
         ,p_segment_type => str_segment_type
         ,p_block_id     => num_block_id
         ,p_tablespace   => str_tablespace
      );
      
      rec_output.p_owner        := str_owner;
      rec_output.p_segment_name := str_segment_name;
      rec_output.p_segment_type := str_segment_type;
      rec_output.p_block_id     := num_block_id;
      rec_output.p_tablespace   := str_tablespace;
      
      pack_statement(
          p_owner          => str_owner
         ,p_segment_name   => str_segment_name
         ,p_segment_type   => str_segment_type
         ,p_block_id       => num_block_id
         ,p_tablespace     => str_tablespace
         ,p_swap_ts        => p_swap_ts
         ,p_statement      => rec_output.p_statement
         ,p_swap_statement => rec_output.p_swap_statement
         ,p_statement_obj  => rec_output.p_swap_segment
      );
      
      PIPE ROW(rec_output);   
       
   END create_hw_pack_statement_pipe;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION move_it(
       p_owner        IN  VARCHAR2
      ,p_segment_name IN  VARCHAR2
      ,p_tablespace   IN  VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2
   AS
      str_segment_type     VARCHAR2(30 Char);
      num_block_id         NUMBER;
      str_tablespace       VARCHAR2(30 Char);
      str_statement        VARCHAR2(2000 Char);
      str_output           VARCHAR2(2000 Char);
      str_statement_object VARCHAR2(30 Char);
      
   BEGIN
   
      get_segment(
          p_owner        => p_owner
         ,p_segment_name => p_segment_name
         ,p_segment_type => str_segment_type
         ,p_block_id     => num_block_id
         ,p_tablespace   => str_tablespace
      );
                  
      IF p_tablespace IS NOT NULL
      THEN
         str_tablespace := p_tablespace;
         
      END IF;
       
      pack_statement(
          p_owner          => p_owner
         ,p_segment_name   => p_segment_name
         ,p_segment_type   => str_segment_type
         ,p_block_id       => num_block_id
         ,p_tablespace     => str_tablespace
         ,p_swap_ts        => str_tablespace
         ,p_statement      => str_statement
         ,p_swap_statement => str_output
         ,p_statement_obj  => str_statement_object
      );
                     
      RETURN str_output;
       
   END move_it;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION move_it_pipe (
       p_owner        IN  VARCHAR2
      ,p_segment_name IN  VARCHAR2
      ,p_tablespace   IN  VARCHAR2 DEFAULT NULL
   ) RETURN quick_pipe PIPELINED
   AS
   BEGIN
      PIPE ROW(
         move_it(
             p_owner        => p_owner
            ,p_segment_name => p_segment_name
            ,p_tablespace   => p_tablespace
         )
      );
      
   END move_it_pipe;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION move_end (
       p_datafile     IN  VARCHAR2
      ,p_tablespace   IN  VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2
   AS
      str_owner            VARCHAR2(30 Char);
      str_segment_name     VARCHAR2(30 Char);
      str_segment_type     VARCHAR2(30 Char);
      num_block_id         NUMBER;
      str_tablespace       VARCHAR2(30 Char);
      str_statement        VARCHAR2(2000 Char);
      str_output           VARCHAR2(2000 Char);
      str_statement_object VARCHAR2(30 Char);
      
   BEGIN
   
      get_hw_segment(
          p_datafile     => p_datafile
         ,p_owner        => str_owner
         ,p_segment_name => str_segment_name
         ,p_segment_type => str_segment_type
         ,p_block_id     => num_block_id
         ,p_tablespace   => str_tablespace
      );
                  
      IF p_tablespace IS NOT NULL
      THEN
         str_tablespace := p_tablespace;
      END IF;
      
      pack_statement(
          p_owner          => str_owner
         ,p_segment_name   => str_segment_name
         ,p_segment_type   => str_segment_type
         ,p_block_id       => num_block_id
         ,p_tablespace     => str_tablespace
         ,p_swap_ts        => str_tablespace
         ,p_statement      => str_statement
         ,p_swap_statement => str_output
         ,p_statement_obj  => str_statement_object
      );
              
      RETURN str_output;
       
   END move_end;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION move_end_pipe (
       p_datafile     IN  VARCHAR2
      ,p_tablespace   IN  VARCHAR2 DEFAULT NULL
   ) RETURN quick_pipe PIPELINED
   AS
   BEGIN
      PIPE ROW(
         move_end(
             p_datafile   => p_datafile
            ,p_tablespace => p_tablespace
         )
      );
       
   END move_end_pipe;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION move_all_pipe (
       p_datafile     IN  VARCHAR2
      ,p_tablespace   IN  VARCHAR2 DEFAULT NULL
   ) RETURN quick_pipe PIPELINED
   AS
      str_sql     VARCHAR2(4000 Char);
      str_move    VARCHAR2(4000 Char);
      ary_owner   MDSYS.SDO_STRING2_ARRAY;
      ary_segment MDSYS.SDO_STRING2_ARRAY;
      hash_check  number_hash;
      
   BEGIN
   
      str_sql := 'SELECT '
              || 'DISTINCT '
              || ' a.owner '
              || ',a.segment_name '
              || 'FROM '
              || 'dba_extents a '
              || 'WHERE '
              || 'a.file_id = ( '
              || '   SELECT '
              || '   b.file_id '
              || '   FROM '
              || '   dba_data_files b '
              || '   WHERE '
              || '   b.file_name = :p1 '
              || ') '
              || 'ORDER BY '
              || 'a.owner ';
              
      EXECUTE IMMEDIATE str_sql 
      BULK COLLECT INTO 
       ary_owner
      ,ary_segment 
      USING p_datafile;
      
      FOR i IN 1 .. ary_owner.COUNT
      LOOP
         
         IF SUBSTR(ary_segment(i),1,4) <> 'BIN$'
         THEN
            str_move := move_it(
                p_owner        => ary_owner(i)
               ,p_segment_name => ary_segment(i)
               ,p_tablespace   => p_tablespace
            );
         
            IF NOT hash_check.EXISTS(str_move)
            THEN
               PIPE ROW(str_move);
               hash_check(str_move) := 1;
               
            END IF;
         
         END IF;
         
      END LOOP;
   
   END move_all_pipe;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION find_voids_pipe (
       p_datafile     IN  VARCHAR2
      ,p_size_minimum IN  NUMBER DEFAULT 2147483648
      ,p_tablespace   IN  VARCHAR2 DEFAULT NULL
   ) RETURN quick_pipe PIPELINED
   AS
      str_sql             VARCHAR2(4000 Char);
      str_tablespace_name VARCHAR2(30 Char);
      num_file_id         NUMBER;
      num_block_size      NUMBER;
      
      TYPE quick_rec IS RECORD (
          owner        VARCHAR2(30 Char)
         ,segment_name VARCHAR2(81 Char)
         ,segment_type VARCHAR2(18 Char)
         ,start_block  NUMBER
         ,end_block    NUMBER
         ,blocks       NUMBER
      );
      TYPE quick_array IS TABLE OF quick_rec
      INDEX BY PLS_INTEGER;
      
      ary_it1    quick_array;
      ary_it2    quick_array;
      num_index2 PLS_INTEGER;
      rec_it     quick_rec;
      num_stop   NUMBER;
      num_gap    NUMBER;
         
   BEGIN
   
      str_sql := 'SELECT '
              || ' b.tablespace_name '
              || ',b.file_id '
              || ',a.block_size '
              || 'FROM '
              || 'dba_tablespaces a '
              || 'JOIN '
              || 'dba_data_files b '
              || 'ON '
              || 'a.tablespace_name = b.tablespace_name '
              || 'WHERE '
              || 'b.file_name = :p1 ';
              
      EXECUTE IMMEDIATE str_sql 
      INTO
       str_tablespace_name
      ,num_file_id
      ,num_block_size 
      USING p_datafile;
  
      str_sql := 'SELECT '
              || ' a.owner '
              || ',a.segment_name '
              || ',a.segment_type '
              || ',a.block_id start_block '
              || ',a.block_id + a.blocks end_block '
              || ',a.blocks '
              || 'FROM '
              || 'dba_extents a '
              || 'WHERE '
              || 'a.file_id = :p1 '
              || 'ORDER BY '
              || 'a.block_id ';
              
      EXECUTE IMMEDIATE str_sql 
      BULK COLLECT INTO ary_it1 
      USING num_file_id;
      
      num_index2 := 0;
      FOR i IN 1 .. ary_it1.COUNT
      LOOP
      
         IF num_index2 = 0
         THEN
            rec_it := ary_it1(i);
            num_index2 := 1;
         ELSE
            IF  ary_it1(i).owner = rec_it.owner
            AND ary_it1(i).segment_name = rec_it.segment_name
            AND ary_it1(i).segment_type = rec_it.segment_type
            AND ary_it1(i).start_block  = rec_it.end_block
            THEN
               rec_it.end_block := ary_it1(i).end_block;
               
            ELSE
               ary_it2(num_index2) := rec_it;
               num_index2 := num_index2 + 1;
               rec_it := ary_it1(i);
               
            END IF;
            
         END IF;
      
      END LOOP;
      
      ary_it2(num_index2) := rec_it;
      
      num_stop := NULL;
      FOR i IN 1 .. ary_it2.COUNT
      LOOP
      
         IF num_stop IS NULL
         THEN
            num_stop := ary_it2(i).end_block;
            PIPE ROW(
               ary_it2(i).owner || '.' || ary_it2(i).segment_name || ':' 
               || TO_CHAR(ary_it2(i).end_block - ary_it2(i).start_block
            ));
            
         ELSE
            IF ary_it2(i).start_block != num_stop
            THEN
               num_gap := (ary_it2(i).start_block - num_stop) * num_block_size;
               IF num_gap >= p_size_minimum
               THEN
                  PIPE ROW('seem to have ' || TO_CHAR(num_gap/1073741824) || ' gig');
                  
               END IF;
               
            END IF;
            
            PIPE ROW(ary_it2(i).owner || '.' || ary_it2(i).segment_name || ':' || TO_CHAR(ary_it2(i).end_block - ary_it2(i).start_block));
            num_stop := ary_it2(i).end_block;
            
         END IF; 
      
      END LOOP;
   
   END find_voids_pipe;
   
END dz_dba_main;
/


--*************************--
PROMPT DZ_DBA_SIZER.pks;

CREATE OR REPLACE PACKAGE dz_dba_sizer
AUTHID CURRENT_USER
AS

   TYPE dz_dba_summary_rec IS RECORD(
       owner                    VARCHAR2(30 Char)
      ,table_name               VARCHAR2(30 Char)
      ,category_type1           VARCHAR2(255 Char)
      ,category_type2           VARCHAR2(255 Char)
      ,category_type3           VARCHAR2(255 Char)
      ,parent_owner             VARCHAR2(30 Char)
      ,parent_table_name        VARCHAR2(30 Char)
      ,item_size_bytes          NUMBER
   );
   TYPE dz_dba_summary_tbl IS TABLE OF dz_dba_summary_rec;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_dba_sizer.get_table_size

   Function to return the size in bytes of a given table as currently stored in 
   the database.  This includes all associated indexes and lob resources 
   including domain tables and specialized datasets such as georaster datasets.

   Parameters:

      p_table_owner       - owner of the table (default USER)
      p_table_name        - table to examine
      p_return_zero_onerr - return zero when object is not found
      p_user_segments     - flag to force use of USER_SEGMENTS

   Returns:

      NUMBER
      
   Notes:
   
      - Access to dba_extents is required in order to obtain the size of 
        resources outside your user connection's schema.  If you are only
        examining resources in your own schema, set p_user_segments to TRUE.
        
      - In many cases permissions for domain tables may not be the same as 
        permissions for the parent table and thus custom permissions or dba 
        access is required to sum all parts of the resource.
        
   */
   FUNCTION get_table_size(
       p_table_owner        IN  VARCHAR2 DEFAULT NULL
      ,p_table_name         IN  VARCHAR2 
      ,p_return_zero_onerr  IN  VARCHAR2 DEFAULT 'FALSE'
      ,p_user_segments      IN  VARCHAR2 DEFAULT 'FALSE' 
   ) RETURN NUMBER;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_simple_table_size(
       p_table_owner        IN  VARCHAR2 DEFAULT NULL
      ,p_table_name         IN  VARCHAR2
      ,p_return_zero_onerr  IN  VARCHAR2 DEFAULT 'FALSE'
      ,p_user_segments      IN  VARCHAR2 DEFAULT 'FALSE' 
   ) RETURN NUMBER;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_dba_sizer.get_object_size

   Function to return the size in bytes of a given table as currently stored in 
   the database.  This does not include any associated resources as summed by
   get_table_size.  This function is utilized by the previous function to 
   examine individual tables for the summation set. 

   Parameters:

      p_segment_owner - owner of the object (default USER)
      p_segment_name  - object to examine
      p_segment_type  - segment type, e.g. TABLE, INDEX, LOBINDEX, etc
      p_user_segments - flag to force use of USER_SEGMENTS

   Returns:

      NUMBER
      
   Notes:
   
      - Access to dba_extents is required in order to obtain the size of 
        resources outside your user connection's schema.  If you are only
        examining resources in your own schema, set p_user_segments to TRUE.
        
      - Note that Index Organized Tables (IOT) return a size of 0 by design as
        the storage is held by the index.
        
   */
   FUNCTION get_object_size(
       p_segment_owner      IN  VARCHAR2 DEFAULT NULL
      ,p_segment_name       IN  VARCHAR2
      ,p_segment_type       IN  VARCHAR2
      ,p_user_segments      IN  VARCHAR2 DEFAULT 'FALSE' 
   ) RETURN NUMBER;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE get_table_indexes(
       p_table_owner        IN  VARCHAR2 DEFAULT NULL
      ,p_table_name         IN  VARCHAR2
      ,p_domain_flag        IN  BOOLEAN DEFAULT NULL
      ,p_index_owners       OUT MDSYS.SDO_STRING2_ARRAY
      ,p_index_names        OUT MDSYS.SDO_STRING2_ARRAY   
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_dba_sizer.get_domain_index_size

   Function to return the size in bytes of a domain index and associated domain
   tables.  Currently supports MDSYS.SPATIAL_INDEX, SDE.ST_SPATIAL_INDEX (10.2.2)
   and CTXSYS.CONTEXT. 

   Parameters:

      p_domain_index_owner - owner of the domain index (default USER)
      p_domain_index_name  - domain index to examine
      p_user_segments      - flag to force use of USER_SEGMENTS

   Returns:

      NUMBER
      
   Notes:
   
      - Access to dba_extents is required in order to obtain the size of 
        resources outside your user connection's schema.  If you are only
        examining resources in your own schema, set p_user_segments to TRUE.
        
      - In many cases permissions for domain tables may not be the same as 
        permissions for the parent table and thus custom permissions or dba 
        access is required to sum all parts of the resource.
        
   */
   FUNCTION get_domain_index_size(
       p_domain_index_owner IN  VARCHAR2 DEFAULT NULL
      ,p_domain_index_name  IN  VARCHAR2
      ,p_user_segments      IN  VARCHAR2 DEFAULT 'FALSE' 
   ) RETURN NUMBER;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_dba_sizer.get_table_lob_size

   Function to return the size in bytes of all lob segements and lob indexes
   tied to columns in a given table. 

   Parameters:

      p_table_owner   - owner of the table (default USER)
      p_table_name    - table to examine
      p_user_segments - flag to force use of USER_SEGMENTS

   Returns:

      NUMBER
      
   Notes:
   
      - Access to dba_extents is required in order to obtain the size of 
        resources outside your user connection's schema.  If you are only
        examining resources in your own schema, set p_user_segments to TRUE.
        
   */
   FUNCTION get_table_lob_size(
       p_table_owner        IN  VARCHAR2 DEFAULT NULL
      ,p_table_name         IN  VARCHAR2
      ,p_user_segments      IN  VARCHAR2 DEFAULT 'FALSE'
   ) RETURN NUMBER;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_dba_sizer.is_complex_object_table

   Function to examine if a given table is the parent table of so-called 
   "complex" object such as a georaster dataset. This logic then leads to 
   specific dataset handling.

   Parameters:

      p_table_owner   - owner of the table (default USER)
      p_table_name    - table to examine
      
   Returns:

      VARCHAR2 - TRUE or FALSE
      
   Notes:
   
      - Only georaster datasets currently supported.
        
   */
   FUNCTION is_complex_object_table(
       p_table_owner        IN  VARCHAR2 DEFAULT NULL
      ,p_table_name         IN  VARCHAR2      
   ) RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE get_sdo_georaster_tables(
       p_table_owner        IN  VARCHAR2 DEFAULT NULL
      ,p_table_name         IN  VARCHAR2
      ,p_table_owners       OUT MDSYS.SDO_STRING2_ARRAY
      ,p_table_names        OUT MDSYS.SDO_STRING2_ARRAY   
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   Function: dz_dba_sizer.schema_summary

   Pipelined function to return the tables in a given schema by a somewhat
   arbitrary three category system. 

   Parameters:

      p_owner - owner of the table (default USER)
      p_user_segments- table to examine

   Returns:

      Table of DZ_DBA_SUMMARY type
      
   Notes:
   
      - Access to dba_extents is required in order to obtain the size of 
        resources outside your user connection's schema.  If you are only
        examining resources in your own schema, leave p_owner empty or 
        set p_user_segments to TRUE.
        
   */
   FUNCTION schema_summary(
       p_owner              IN  VARCHAR2 DEFAULT NULL
      ,p_user_segments      IN  VARCHAR2 DEFAULT 'FALSE'
   ) RETURN dz_dba_summary_list PIPELINED;

END dz_dba_sizer;
/

GRANT EXECUTE ON dz_dba_sizer TO PUBLIC;


--*************************--
PROMPT DZ_DBA_SIZER.pkb;

CREATE OR REPLACE PACKAGE BODY dz_dba_sizer
AS

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_table_size(
       p_table_owner        IN  VARCHAR2 DEFAULT NULL
      ,p_table_name         IN  VARCHAR2
      ,p_return_zero_onerr  IN  VARCHAR2 DEFAULT 'FALSE'
      ,p_user_segments      IN  VARCHAR2 DEFAULT 'FALSE'
   ) RETURN NUMBER
   AS
      str_table_owner  VARCHAR2(30 Char) := p_table_owner;
      num_table_size   NUMBER := 0;
      ary_owners       MDSYS.SDO_STRING2_ARRAY := MDSYS.SDO_STRING2_ARRAY();
      ary_names        MDSYS.SDO_STRING2_ARRAY := MDSYS.SDO_STRING2_ARRAY();

   BEGIN

      IF str_table_owner IS NULL
      THEN
         str_table_owner := USER;

      END IF;

      IF dz_dba_util.table_exists(
          p_owner       => str_table_owner
         ,p_table_name  => p_table_name
      ) = 'FALSE'
      THEN
         IF p_return_zero_onerr = 'TRUE'
         THEN
            RETURN 0;

         ELSE
            RAISE_APPLICATION_ERROR(-20001,'table not found');

         END IF;

      END IF;

      -- First get table size alone
      num_table_size := num_table_size + get_object_size(
          p_segment_owner => str_table_owner
         ,p_segment_name  => p_table_name
         ,p_segment_type  => 'TABLE'
         ,p_user_segments => p_user_segments
      );

      -- Second, get the table LOBs
      num_table_size := num_table_size + get_table_lob_size(
          p_table_owner   => str_table_owner
         ,p_table_name    => p_table_name
         ,p_user_segments => p_user_segments
      );

      -- Third, get size of all nondomain indexes
      get_table_indexes(
          p_table_owner   => str_table_owner
         ,p_table_name    => p_table_name
         ,p_domain_flag   => FALSE
         ,p_index_owners  => ary_owners
         ,p_index_names   => ary_names
      );

      FOR i IN 1 .. ary_names.COUNT
      LOOP
         num_table_size := num_table_size + get_object_size(
             p_segment_owner => ary_owners(i)
            ,p_segment_name  => ary_names(i)
            ,p_segment_type  => 'INDEX'
            ,p_user_segments => p_user_segments
         );

      END LOOP;

      -- Fourth, get size of all domain indexes
      get_table_indexes(
          p_table_owner   => str_table_owner
         ,p_table_name    => p_table_name
         ,p_domain_flag   => TRUE
         ,p_index_owners  => ary_owners
         ,p_index_names   => ary_names
      );

      FOR i IN 1 .. ary_names.COUNT
      LOOP
         num_table_size := num_table_size + get_domain_index_size(
             p_domain_index_owner => ary_owners(i)
            ,p_domain_index_name  => ary_names(i)
            ,p_user_segments      => p_user_segments
         );

      END LOOP;

      -- Fifth, I once had code to determine SDELOB size, now removed

      -- Sixth, check if table is complex object table, SDO_GEORASTER is the only type for now
      IF is_complex_object_table(
          p_table_owner  => str_table_owner
         ,p_table_name   => p_table_name
      ) = 'SDO_GEORASTER'
      THEN
         get_sdo_georaster_tables(
             p_table_owner  => str_table_owner
            ,p_table_name   => p_table_name
            ,p_table_owners => ary_owners
            ,p_table_names  => ary_names
         );

         FOR i IN 1 .. ary_names.COUNT
         LOOP
            num_table_size := num_table_size + get_table_size(
                p_table_owner   => ary_owners(i)
               ,p_table_name    => ary_names(i)
               ,p_user_segments => p_user_segments
            );

         END LOOP;

      END IF;

      RETURN num_table_size;

   END get_table_size;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_simple_table_size(
       p_table_owner        IN  VARCHAR2 DEFAULT NULL
      ,p_table_name         IN  VARCHAR2
      ,p_return_zero_onerr  IN  VARCHAR2 DEFAULT 'FALSE'
      ,p_user_segments      IN  VARCHAR2 DEFAULT 'FALSE'
   ) RETURN NUMBER
   AS
      str_table_owner  VARCHAR2(30 Char) := p_table_owner;
      num_table_size   NUMBER := 0;
      ary_owners       MDSYS.SDO_STRING2_ARRAY := MDSYS.SDO_STRING2_ARRAY();
      ary_names        MDSYS.SDO_STRING2_ARRAY := MDSYS.SDO_STRING2_ARRAY();

   BEGIN

      IF str_table_owner IS NULL
      THEN
         str_table_owner := USER;

      END IF;

      IF dz_dba_util.table_exists(
          p_owner       => str_table_owner
         ,p_table_name  => p_table_name
      ) = 'FALSE'
      THEN
         IF p_return_zero_onerr = 'TRUE'
         THEN
            RETURN 0;

         ELSE
            RAISE_APPLICATION_ERROR(-20001,'table not found');

         END IF;

      END IF;

      -- First get table size alone
      num_table_size := num_table_size + get_object_size(
          p_segment_owner => str_table_owner
         ,p_segment_name  => p_table_name
         ,p_segment_type  => 'TABLE'
         ,p_user_segments => p_user_segments
      );

      -- Second, get the table LOBs
      num_table_size := num_table_size + get_table_lob_size(
          p_table_owner   => str_table_owner
         ,p_table_name    => p_table_name
         ,p_user_segments => p_user_segments
      );

      -- Third, get size of all nondomain indexes
      get_table_indexes(
          p_table_owner   => str_table_owner
         ,p_table_name    => p_table_name
         ,p_domain_flag   => FALSE
         ,p_index_owners  => ary_owners
         ,p_index_names   => ary_names
      );

      FOR i IN 1 .. ary_names.COUNT
      LOOP
         num_table_size := num_table_size + get_object_size(
             p_segment_owner => ary_owners(i)
            ,p_segment_name  => ary_names(i)
            ,p_segment_type  => 'INDEX'
            ,p_user_segments => p_user_segments
         );

      END LOOP;

      RETURN num_table_size;

   END get_simple_table_size;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_object_size(
       p_segment_owner      IN  VARCHAR2 DEFAULT NULL
      ,p_segment_name       IN  VARCHAR2
      ,p_segment_type       IN  VARCHAR2
      ,p_user_segments      IN  VARCHAR2 DEFAULT 'FALSE'
   ) RETURN NUMBER
   AS
      str_segment_owner   VARCHAR2(30 Char) := p_segment_owner;
      str_sql             VARCHAR2(4000 Char);
      str_iot_type        VARCHAR2(255 Char);
      str_owner           VARCHAR2(30 Char);
      str_index_name      VARCHAR2(30 Char);
      num_bytes           NUMBER;
      str_tablespace_name VARCHAR2(30 Char);
      str_segment_type    VARCHAR2(255 Char);
      num_rows            NUMBER;

   BEGIN

      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF str_segment_owner IS NULL
      THEN
         str_segment_owner := USER;

      END IF;

      --------------------------------------------------------------------------
      -- Step 20
      -- Check if table is actually IOT
      --------------------------------------------------------------------------
      BEGIN
         SELECT
          a.iot_type
         ,b.owner
         ,b.index_name
         INTO
          str_iot_type
         ,str_owner
         ,str_index_name
         FROM
         all_all_tables a
         JOIN (
            SELECT
             bb.owner
            ,bb.index_name
            ,bb.table_name
            ,bb.table_owner
            FROM
            all_indexes bb
            WHERE
            bb.index_type = 'IOT - TOP'
         ) b
         ON
             a.owner = b.table_owner
         AND a.table_name = b.table_name
         WHERE
             a.owner      = str_segment_owner
         AND a.table_name = p_segment_name;

      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            str_iot_type := NULL;

         WHEN OTHERS
         THEN
            RAISE;

      END;

      IF str_iot_type = 'IOT'
      THEN
         RETURN 0;

      END IF;

      --------------------------------------------------------------------------
      -- Step 30
      -- Allow user_segments override if requested
      --------------------------------------------------------------------------
      IF p_user_segments = 'TRUE'
      THEN
         BEGIN
            SELECT
             a.bytes
            ,a.tablespace_name
            ,a.segment_type
            ,b.num_rows
            INTO
             num_bytes
            ,str_tablespace_name
            ,str_segment_type
            ,num_rows
            FROM
            user_segments a
            LEFT JOIN
            user_tables b
            ON
            a.segment_name = b.table_name
            WHERE
                a.segment_type = p_segment_type
            AND a.segment_name = p_segment_name;
            
             RETURN num_bytes;

         EXCEPTION
            -- Post 11g delayed segment creation just means size 0
            WHEN NO_DATA_FOUND
            THEN
               RETURN 0;

            WHEN OTHERS
            THEN
               RAISE;

         END;

      ELSE

         --------------------------------------------------------------------------
         -- Step 40
         -- Otherwise query dba_segments
         --------------------------------------------------------------------------
         str_sql := 'SELECT '
                 || ' a.bytes '
                 || ',a.tablespace_name '
                 || ',a.segment_type '
                 || ',b.num_rows '
                 || 'FROM '
                 || 'dba_segments a '
                 || 'LEFT JOIN '
                 || 'all_all_tables b '
                 || 'ON '
                 || '    a.segment_name = b.table_name '
                 || 'AND a.owner = b.owner '
                 || 'WHERE '
                 || '    a.owner = :p01 '
                 || 'AND a.segment_type = :p02 '
                 || 'AND a.segment_name = :p03 ';

          BEGIN
            EXECUTE IMMEDIATE str_sql
            INTO
             num_bytes
            ,str_tablespace_name
            ,str_segment_type
            ,num_rows
            USING
             str_segment_owner
            ,p_segment_type
            ,p_segment_name;

            RETURN num_bytes;

         EXCEPTION
            -- Post 11g delayed segment creation just means size 0
            WHEN NO_DATA_FOUND
            THEN
               RETURN 0;

            WHEN OTHERS
            THEN
               RAISE;

         END;
         
      END IF;

   END get_object_size;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE get_table_indexes(
       p_table_owner        IN  VARCHAR2 DEFAULT NULL
      ,p_table_name         IN  VARCHAR2
      ,p_domain_flag        IN  BOOLEAN DEFAULT NULL
      ,p_index_owners       OUT MDSYS.SDO_STRING2_ARRAY
      ,p_index_names        OUT MDSYS.SDO_STRING2_ARRAY
   )
   AS
      str_table_owner VARCHAR2(30 Char) := p_table_owner;

   BEGIN

      IF str_table_owner IS NULL
      THEN
         str_table_owner := USER;

      END IF;

      IF p_domain_flag IS NULL
      THEN
         SELECT
          a.owner
         ,a.index_name
         BULK COLLECT INTO
          p_index_owners
         ,p_index_names
         FROM
         all_indexes a
         WHERE
             a.table_owner = str_table_owner
         AND a.table_name = p_table_name;

      ELSIF p_domain_flag = TRUE
      THEN
         SELECT
          a.owner
         ,a.index_name
         BULK COLLECT INTO
          p_index_owners
         ,p_index_names
         FROM
         all_indexes a
         WHERE
             a.table_owner = str_table_owner
         AND a.table_name = p_table_name
         AND a.index_type = 'DOMAIN';

      ELSIF p_domain_flag = FALSE
      THEN
         SELECT
          a.owner
         ,a.index_name
         BULK COLLECT INTO
          p_index_owners
         ,p_index_names
         FROM
         all_indexes a
         WHERE
             a.table_owner = str_table_owner
         AND a.table_name = p_table_name
         AND a.index_type <> 'DOMAIN';

      ELSE
         RAISE_APPLICATION_ERROR(-20001,'error');

      END IF;

   END get_table_indexes;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_domain_index_size(
       p_domain_index_owner IN  VARCHAR2 DEFAULT NULL
      ,p_domain_index_name  IN  VARCHAR2
      ,p_user_segments      IN  VARCHAR2 DEFAULT 'FALSE'
   ) RETURN NUMBER
   AS
      str_sql         VARCHAR2(4000 Char);
      str_domain_index_owner VARCHAR2(30 Char) := p_domain_index_owner;
      str_owner       VARCHAR2(30 Char);
      str_index_name  VARCHAR2(30 Char);
      str_ityp_owner  VARCHAR2(30 Char);
      str_ityp_name   VARCHAR2(30 Char);
      str_table_owner VARCHAR2(30 Char);
      str_table_name  VARCHAR2(30 Char);
      str_spidx_owner VARCHAR2(30 Char);
      str_spidx_name  VARCHAR2(30 Char);
      str_mdxt_name   VARCHAR2(30 Char);
      str_ctx_name    VARCHAR2(30 Char);
      num_sde_geom_id NUMBER;
      num_size        NUMBER;

   BEGIN

      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF str_domain_index_owner IS NULL
      THEN
         str_domain_index_owner := USER;

      END IF;

      --------------------------------------------------------------------------
      -- Step 20
      -- Verify that object is a domain index
      --------------------------------------------------------------------------
      BEGIN
         SELECT
          a.owner
         ,a.index_name
         ,a.ityp_owner
         ,a.ityp_name
         ,a.table_owner
         ,a.table_name
         INTO
          str_owner
         ,str_index_name
         ,str_ityp_owner
         ,str_ityp_name
         ,str_table_owner
         ,str_table_name
         FROM
         all_indexes a
         WHERE
             a.owner = str_domain_index_owner
         AND a.index_name = p_domain_index_name
         AND a.index_type = 'DOMAIN';

      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            RAISE_APPLICATION_ERROR(
                -20001
               ,'could not find a domain index named ' || p_domain_index_name
            );

         WHEN OTHERS
         THEN
            RAISE;

      END;

      --------------------------------------------------------------------------
      -- Step 30
      -- Process MDSYS.SPATIAL_INDEX
      --------------------------------------------------------------------------
      IF str_ityp_owner = 'MDSYS'
      AND str_ityp_name = 'SPATIAL_INDEX'
      THEN
         SELECT
          a.sdo_index_owner
         ,a.sdo_index_table
         INTO
          str_spidx_owner
         ,str_spidx_name
         FROM
         all_sdo_index_metadata a
         WHERE
             a.sdo_index_owner = str_owner
         AND a.sdo_index_name = str_index_name;

         num_size := get_table_size(
             p_table_owner   => str_spidx_owner
            ,p_table_name    => str_spidx_name
            ,p_user_segments => p_user_segments
         );

         -- Account for new MDXT domain tables
         str_mdxt_name := REPLACE(
             str_spidx_name
            ,'MDRT'
            ,'MDXT'
         );

         num_size := num_size + get_table_size(
             p_table_owner       => str_spidx_owner
            ,p_table_name        => str_mdxt_name
            ,p_return_zero_onerr => 'TRUE'
            ,p_user_segments     => p_user_segments
         );

         RETURN num_size;

      --------------------------------------------------------------------------
      -- Step 40
      -- Process SDE.ST_SPATIAL_INDEX
      --------------------------------------------------------------------------
      ELSIF str_ityp_owner = 'SDE'
      AND str_ityp_name = 'ST_SPATIAL_INDEX'
      THEN
         str_sql := 'SELECT '
                 || 'a.geom_id '
                 || 'FROM '
                 || 'sde.st_geometry_columns a '
                 || 'WHERE '
                 || '    a.owner = :p01 '
                 || 'AND a.table_name = :p02 ';

         EXECUTE IMMEDIATE str_sql
         INTO
         num_sde_geom_id
         USING
          str_table_owner
         ,str_table_name;

         num_size := get_table_size(
             p_table_owner       => str_table_owner
            ,p_table_name        => 'S' || TO_CHAR(num_sde_geom_id) || '_IDX$'
            ,p_return_zero_onerr => 'TRUE'
            ,p_user_segments     => p_user_segments
         );

         RETURN num_size + get_table_size(
             p_table_owner       => str_table_owner
            ,p_table_name        => 'S' || TO_CHAR(num_sde_geom_id) || '$_IX1'
            ,p_return_zero_onerr => 'TRUE'
            ,p_user_segments     => p_user_segments
         ) + get_table_size(
             p_table_owner       => str_table_owner
            ,p_table_name        => 'S' || TO_CHAR(num_sde_geom_id) || '$_IX2'
            ,p_return_zero_onerr => 'TRUE'
            ,p_user_segments     => p_user_segments
         );

      --------------------------------------------------------------------------
      -- Step 50
      -- Process CTXSYS.CONTEXT
      --------------------------------------------------------------------------
      ELSIF str_ityp_owner = 'CTXSYS'
      AND str_ityp_name = 'CONTEXT'
      THEN
         IF p_user_segments = 'TRUE'
         THEN
            str_sql := 'SELECT '
                    || 'a.idx_name '
                    || 'FROM '
                    || 'ctxsys.ctx_user_indexes a '
                    || 'WHERE '
                    || '    a.idx_table_owner = :p01 '
                    || 'AND a.idx_table= :p02 ';

         ELSE
            str_sql := 'SELECT '
                    || 'a.idx_name '
                    || 'FROM '
                    || 'ctxsys.ctx_indexes a '
                    || 'WHERE '
                    || '    a.idx_table_owner = :p01 '
                    || 'AND a.idx_table= :p02 ';

         END IF;

         EXECUTE IMMEDIATE str_sql
         INTO
         str_ctx_name
         USING
          str_table_owner
         ,str_table_name;

         RETURN get_table_size(
             p_table_owner       => str_table_owner
            ,p_table_name        => 'DR$' || str_ctx_name || '$I'
            ,p_return_zero_onerr => 'TRUE'
            ,p_user_segments     => p_user_segments
         ) + get_table_size(
             p_table_owner       => str_table_owner
            ,p_table_name        => 'DR$' || str_ctx_name || '$K'
            ,p_return_zero_onerr => 'TRUE'
            ,p_user_segments     => p_user_segments
         ) + get_table_size(
             p_table_owner       => str_table_owner
            ,p_table_name        => 'DR$' || str_ctx_name || '$N'
            ,p_return_zero_onerr => 'TRUE'
            ,p_user_segments     => p_user_segments
         ) + get_table_size(
             p_table_owner       => str_table_owner
            ,p_table_name        => 'DR$' || str_ctx_name || '$R'
            ,p_return_zero_onerr => 'TRUE'
            ,p_user_segments     => p_user_segments
         );

      --------------------------------------------------------------------------
      -- Step 60
      -- Fail if something else
      --------------------------------------------------------------------------
      ELSE
         RAISE_APPLICATION_ERROR(-20001,'unhandled domain index type');

      END IF;

   END get_domain_index_size;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_table_lob_size(
       p_table_owner        IN  VARCHAR2 DEFAULT NULL
      ,p_table_name         IN  VARCHAR2
      ,p_user_segments      IN  VARCHAR2 DEFAULT 'FALSE'
   ) RETURN NUMBER
   AS
      num_lob_size     NUMBER := 0;
      ary_lob_segments MDSYS.SDO_STRING2_ARRAY;
      ary_lob_indexes  MDSYS.SDO_STRING2_ARRAY;

   BEGIN

      SELECT
       a.segment_name
      ,a.index_name
      BULK COLLECT INTO
       ary_lob_segments
      ,ary_lob_indexes
      FROM
      all_lobs a
      WHERE
          a.owner = p_table_owner
      AND a.table_name = p_table_name;

      IF ary_lob_segments IS NULL
      OR ary_lob_segments.COUNT = 0
      THEN
         RETURN 0;

      END IF;

      FOR i IN 1 .. ary_lob_segments.COUNT
      LOOP
         num_lob_size := num_lob_size + get_object_size(
             p_segment_owner => p_table_owner
            ,p_segment_name  => ary_lob_segments(i)
            ,p_segment_type  => 'LOBSEGMENT'
            ,p_user_segments => p_user_segments
         );

         num_lob_size := num_lob_size + get_object_size(
             p_segment_owner => p_table_owner
            ,p_segment_name  => ary_lob_indexes(i)
            ,p_segment_type  => 'LOBINDEX'
            ,p_user_segments => p_user_segments
         );

      END LOOP;

      RETURN num_lob_size;

   END get_table_lob_size;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION is_complex_object_table(
       p_table_owner        IN  VARCHAR2 DEFAULT NULL
      ,p_table_name         IN  VARCHAR2
   ) RETURN VARCHAR2
   AS
      str_table_owner VARCHAR2(30 Char) := p_table_owner;
      str_data_type   VARCHAR2(255 Char);

   BEGIN

      IF str_table_owner IS NULL
      THEN
         str_table_owner := USER;

      END IF;

      SELECT
      b.data_type
      INTO
      str_data_type
      FROM
      all_all_tables a
      JOIN (
         SELECT DISTINCT
          bb.owner
         ,bb.table_name
         ,bb.data_type
         FROM
         all_tab_columns bb
         WHERE
             bb.owner = str_table_owner
         AND bb.table_name = p_table_name
         AND bb.data_type IN ('SDO_GEORASTER')
      ) b
      ON
          a.owner = b.owner
      AND a.table_name = b.table_name;

      RETURN str_data_type;

   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         RETURN NULL;

      WHEN OTHERS
      THEN
         RAISE;

   END is_complex_object_table;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE get_sdo_georaster_tables(
       p_table_owner        IN  VARCHAR2 DEFAULT NULL
      ,p_table_name         IN  VARCHAR2
      ,p_table_owners       OUT MDSYS.SDO_STRING2_ARRAY
      ,p_table_names        OUT MDSYS.SDO_STRING2_ARRAY
   )
   AS
      str_sql         VARCHAR2(4000 Char);
      str_table_owner VARCHAR2(30 Char) := p_table_owner;
      str_column_name VARCHAR2(30 Char);

   BEGIN

      IF str_table_owner IS NULL
      THEN
         str_table_owner := USER;

      END IF;

      -- First collect the SDO_GEORASTER column, I guess we can assume there is only one?
      BEGIN
         SELECT
         b.column_name
         INTO str_column_name
         FROM
         all_all_tables a
         JOIN (
            SELECT DISTINCT
             bb.owner
            ,bb.table_name
            ,bb.data_type
            ,bb.column_name
            FROM
            all_tab_columns bb
            WHERE
                bb.owner = str_table_owner
            AND bb.table_name = p_table_name
            AND bb.data_type IN ('SDO_GEORASTER')
         ) b
         ON
             a.owner = b.owner
         AND a.table_name = b.table_name;

      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
             RAISE_APPLICATION_ERROR(
                 -20001
                ,'cannot find SDO_GEORASTER column in ' || p_table_name
             );

         WHEN OTHERS
         THEN
            RAISE;

      END;

      -- Second get the child table names out of the objects
      str_sql := 'SELECT '
              || ' ''' || str_table_owner || ''''
              || ',a.' || str_column_name || '.RASTERDATATABLE a '
              || 'FROM '
              || str_table_owner || '.' || p_table_name || ' a ';

      EXECUTE IMMEDIATE str_sql
      BULK COLLECT INTO
       p_table_owners
      ,p_table_names;

   END get_sdo_georaster_tables;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION schema_summary(
       p_owner              IN  VARCHAR2 DEFAULT NULL
      ,p_user_segments      IN  VARCHAR2 DEFAULT 'FALSE'
   ) RETURN dz_dba_summary_list PIPELINED
   AS
      str_owner         VARCHAR2(30 Char) := UPPER(p_owner);
      str_user_segments VARCHAR2(30 Char) := UPPER(p_user_segments);
      num_check         NUMBER;
      num_esri          NUMBER;
      num_ctx           NUMBER;
      int_index         NUMBER;
      str_sql           VARCHAR2(4000 Char);
      ary_internal_list dz_dba_summary_tbl;
      ary_tables        dz_dba_summary_list := dz_dba_summary_list();
      ary_tmp_load      dz_dba_summary_list := dz_dba_summary_list();
      ary_georasters    dz_dba_summary_list := dz_dba_summary_list();
      ary_rasters       dz_dba_summary_list := dz_dba_summary_list();
      ary_topologies    dz_dba_summary_list := dz_dba_summary_list();
      ary_ndms          dz_dba_summary_list := dz_dba_summary_list();
      ary_ctxs          dz_dba_summary_list := dz_dba_summary_list();
      ary_sde_geometry  dz_dba_summary_list := dz_dba_summary_list();
      ary_sde_domain    dz_dba_summary_list := dz_dba_summary_list();
      ary_sdo_geometry  dz_dba_summary_list := dz_dba_summary_list();
      ary_sdo_domain    dz_dba_summary_list := dz_dba_summary_list();

      --------------------------------------------------------------------------
      FUNCTION c2t(
          p_input   IN  dz_dba_summary_tbl
      ) RETURN dz_dba_summary_list
      AS
         ary_output dz_dba_summary_list := dz_dba_summary_list();

      BEGIN

         IF p_input IS NULL
         OR p_input.COUNT = 0
         THEN
            RETURN ary_output;

         END IF;

         ary_output.EXTEND(p_input.COUNT);
         FOR i IN 1 .. p_input.COUNT
         LOOP
            ary_output(i)                   := dz_dba_summary();
            ary_output(i).owner             := p_input(i).owner;
            ary_output(i).table_name        := p_input(i).table_name;
            ary_output(i).category_type1    := p_input(i).category_type1;
            ary_output(i).category_type2    := p_input(i).category_type2;
            ary_output(i).category_type3    := p_input(i).category_type3;
            ary_output(i).parent_owner      := p_input(i).parent_owner;
            ary_output(i).parent_table_name := p_input(i).parent_table_name;
            ary_output(i).item_size_bytes   := p_input(i).item_size_bytes;

         END LOOP;

         RETURN ary_output;

      END c2t;

      --------------------------------------------------------------------------
      PROCEDURE append_ary(
          p_target  IN OUT NOCOPY dz_dba_summary_list
         ,p_source  IN dz_dba_summary_list
      )
      AS
         int_index NUMBER;

      BEGIN

         IF p_target IS NULL
         THEN
            p_target := dz_dba_summary_list();

         END IF;

         IF p_source IS NULL
         OR p_source.COUNT = 0
         THEN
            RETURN;

         END IF;

         int_index := p_target.COUNT + 1;
         p_target.EXTEND(p_source.COUNT);

         FOR i IN 1 .. p_source.COUNT
         LOOP
            p_target(int_index) := p_source(i);
            int_index := int_index + 1;

         END LOOP;

      END append_ary;

   BEGIN

      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF str_owner IS NULL
      THEN
         str_owner := USER;
         str_user_segments := 'TRUE';

      END IF;

      IF str_user_segments IS NULL
      OR str_user_segments NOT IN ('TRUE','FALSE')
      THEN
         str_user_segments := 'FALSE';

      ELSIF str_user_segments = 'TRUE'
      AND   str_owner <> USER
      THEN
         RAISE_APPLICATION_ERROR(
             -20001
            ,'your user_segments cannot measure this schema'
         );

      END IF;

      --------------------------------------------------------------------------
      -- Step 20
      -- Verify user existence
      --------------------------------------------------------------------------
      SELECT
      COUNT(*)
      INTO num_check
      FROM
      all_users a
      WHERE
      a.username = str_owner;

      IF num_check IS NULL
      OR num_check = 0
      THEN
         RAISE_APPLICATION_ERROR(-20001,'Unknown user ' || str_owner);

      END IF;

      SELECT
      COUNT(*)
      INTO num_esri
      FROM
      all_users a
      WHERE
      a.username = 'SDE';

      SELECT
      COUNT(*)
      INTO num_ctx
      FROM
      all_users a
      WHERE
      a.username = 'CTXSYS';

      --------------------------------------------------------------------------
      -- Step 30
      -- First collect any georaster tables
      --------------------------------------------------------------------------
      SELECT
       a.owner
      ,a.table_name
      ,a.column_name
      ,'RASTER'
      ,'RASTER'
      ,NULL
      ,NULL
      ,NULL
      BULK COLLECT INTO ary_internal_list
      FROM
      all_tab_columns a
      WHERE
          a.owner = str_owner
      AND a.data_type_owner IN ('MDSYS','PUBLIC')
      AND a.data_type = 'SDO_GEORASTER'
      ORDER BY
       a.owner
      ,a.table_name
      ,a.column_name;

      ary_georasters := c2t(ary_internal_list);

      --------------------------------------------------------------------------
      -- Step 40
      -- Second harvest the names of the raster tables
      --------------------------------------------------------------------------
      FOR i IN 1 .. ary_georasters.COUNT
      LOOP
         str_sql := 'SELECT '
                 || ' ''' || ary_georasters(i).owner || ''''
                 || ',a.' || ary_georasters(i).category_type1 || '.RASTERDATATABLE '
                 || ',''RASTER'' '
                 || ',''RASTER'' '
                 || ',''RASTER'' '
                 || ',''' || ary_georasters(i).owner || ''''
                 || ',''' || ary_georasters(i).table_name || ''''
                 || ',NULL '
                 || 'FROM '
                 || ary_georasters(i).owner || '.' || ary_georasters(i).table_name || ' a '
                 || 'WHERE '
                 || 'a.' || ary_georasters(i).category_type1 || ' IS NOT NULL ';

         EXECUTE IMMEDIATE str_sql
         BULK COLLECT INTO ary_internal_list;

         append_ary(
             ary_rasters
            ,c2t(ary_internal_list)
         );

      END LOOP;

      --------------------------------------------------------------------------
      -- Step 50
      -- Next collect any topologies in the schema
      --------------------------------------------------------------------------
      WITH topologies AS (
         SELECT
          a.owner
         ,a.topology
         FROM
         all_sdo_topo_info a
         WHERE
         a.owner = str_owner
         GROUP BY
          a.owner
         ,a.topology
      )
      SELECT
       a.owner
      ,a.table_name
      ,'MDSYS.SDO_TOPO'
      ,'MDSYS.SDO_TOPO'
      ,'TOPOLOGY'
      ,a.parent_owner
      ,a.parent_table_name
      ,NULL
      BULK COLLECT INTO ary_internal_list
      FROM (
         SELECT
          aa.owner
         ,aa.topology || '_EDGE$' AS table_name
         ,aa.owner AS parent_owner
         ,aa.topology AS parent_table_name
         FROM
         topologies aa
         UNION ALL
         SELECT
          bb.owner
         ,bb.topology || '_FACE$' AS table_name
         ,bb.owner AS parent_owner
         ,bb.topology AS parent_table_name
         FROM
         topologies bb
         UNION ALL
         SELECT
          cc.owner
         ,cc.topology || '_NODE$' AS table_name
         ,cc.owner AS parent_owner
         ,cc.topology AS parent_table_name
         FROM
         topologies cc
         UNION ALL
         SELECT
          dd.owner
         ,dd.topology || '_HISTORY$' AS table_name
         ,dd.owner AS parent_owner
         ,dd.topology AS parent_table_name
         FROM
         topologies dd
         UNION ALL
         SELECT
          ee.owner
         ,ee.topology || '_RELATION$' AS table_name
         ,ee.owner AS parent_owner
         ,ee.topology AS parent_table_name
         FROM
         topologies ee
         UNION ALL
         SELECT
          ff.owner
         ,ff.topology || '_EXP$' AS table_name
         ,ff.owner AS parent_owner
         ,ff.topology AS parent_table_name
         FROM
         topologies ff
      ) a;

      ary_topologies := c2t(ary_internal_list);

      --------------------------------------------------------------------------
      -- Step 60
      -- Next collect any ndms in the schema
      --------------------------------------------------------------------------
      WITH ndms AS (
         SELECT
          a.owner
         ,a.network
         ,a.lrs_table_name
         ,a.node_table_name
         ,a.link_table_name
         ,a.path_table_name
         ,a.path_link_table_name
         ,a.subpath_table_name
         ,a.partition_table_name
         ,a.partition_blob_table_name
         ,a.component_table_name
         ,a.node_level_table_name
         FROM
         all_sdo_network_metadata a
         WHERE
         a.owner = str_owner
      )
      SELECT
       a.owner
      ,a.table_name
      ,'MDSYS.SDO_NET'
      ,'MDSYS.SDO_NET'
      ,'NETWORK'
      ,a.parent_owner
      ,a.parent_table_name
      ,NULL
      BULK COLLECT INTO ary_internal_list
      FROM (
         SELECT
          aa.owner
         ,aa.lrs_table_name AS table_name
         ,aa.owner AS parent_owner
         ,aa.network AS parent_table_name
         FROM
         ndms aa
         WHERE
         aa.lrs_table_name IS NOT NULL
         UNION ALL
         SELECT
          bb.owner
         ,bb.node_table_name
         ,bb.owner AS parent_owner
         ,bb.network AS parent_table_name
         FROM
         ndms bb
         WHERE
         bb.node_table_name IS NOT NULL
         UNION ALL
         SELECT
          cc.owner
         ,cc.link_table_name
         ,cc.owner AS parent_owner
         ,cc.network AS parent_table_name
         FROM
         ndms cc
         WHERE
         cc.link_table_name IS NOT NULL
         UNION ALL
         SELECT
          dd.owner
         ,dd.path_table_name
         ,dd.owner AS parent_owner
         ,dd.network AS parent_table_name
         FROM
         ndms dd
         WHERE
         dd.path_table_name IS NOT NULL
         UNION ALL
         SELECT
          ee.owner
         ,ee.path_link_table_name
         ,ee.owner AS parent_owner
         ,ee.network AS parent_table_name
         FROM
         ndms ee
         WHERE
         ee.path_link_table_name IS NOT NULL
         UNION ALL
         SELECT
          ff.owner
         ,ff.subpath_table_name
         ,ff.owner AS parent_owner
         ,ff.network AS parent_table_name
         FROM
         ndms ff
         WHERE
         ff.subpath_table_name IS NOT NULL
         UNION ALL
         SELECT
          gg.owner
         ,gg.partition_table_name
         ,gg.owner AS parent_owner
         ,gg.network AS parent_table_name
         FROM
         ndms gg
         WHERE
         gg.partition_table_name IS NOT NULL
         UNION ALL
         SELECT
          hh.owner
         ,hh.partition_blob_table_name
         ,hh.owner AS parent_owner
         ,hh.network AS parent_table_name
         FROM
         ndms hh
         WHERE
         hh.partition_blob_table_name IS NOT NULL
         UNION ALL
         SELECT
          ii.owner
         ,ii.component_table_name
         ,ii.owner AS parent_owner
         ,ii.network AS parent_table_name
         FROM
         ndms ii
         WHERE
         ii.component_table_name IS NOT NULL
         UNION ALL
         SELECT
          jj.owner
         ,jj.node_level_table_name
         ,jj.owner AS parent_owner
         ,jj.network AS parent_table_name
         FROM
         ndms jj
         WHERE
         jj.node_level_table_name IS NOT NULL
      ) a
      GROUP BY
       a.owner
      ,a.table_name
      ,a.parent_owner
      ,a.parent_table_name;

      ary_ndms := c2t(ary_internal_list);

      --------------------------------------------------------------------------
      -- Step 70
      -- harvest any SDE.ST_GEOMETRY domain tables
      --------------------------------------------------------------------------
      IF num_esri = 1
      THEN
         str_sql := 'SELECT '
                 || ' a.owner '
                 || ',a.table_name '
                 || ',''SDE.ST_GEOMETRY'' '
                 || ',''SDE.ST_GEOMETRY'' '
                 || ',''FEATURE CLASS'' '
                 || ',NULL '
                 || ',NULL '
                 || ',NULL '
                 || 'FROM '
                 || 'sde.st_geometry_columns a '
                 || 'WHERE '
                 || 'a.owner = :p01 ';

         EXECUTE IMMEDIATE str_sql
         BULK COLLECT INTO ary_internal_list
         USING str_owner;

         ary_sde_geometry := c2t(ary_internal_list);

         str_sql := 'SELECT '
                 || ' a.owner '
                 || ',''S'' || a.geom_id || ''_IDX$'' '
                 || ',''SDE.ST_SPATIAL_INDEX'' '
                 || ',''SDE.ST_GEOMETRY'' '
                 || ',''FEATURE CLASS'' '
                 || ',a.owner '
                 || ',a.table_name '
                 || ',NULL '
                 || 'FROM '
                 || 'sde.st_geometry_columns a '
                 || 'WHERE '
                 || 'a.owner = :p01 ';

         EXECUTE IMMEDIATE str_sql
         BULK COLLECT INTO ary_internal_list
         USING str_owner;

         ary_sde_domain := c2t(ary_internal_list);

      END IF;

      --------------------------------------------------------------------------
      -- Step 80
      -- harvest any MDSYS.SDO_TOPO_GEOMETRY spatial tables
      --------------------------------------------------------------------------
      SELECT
       a.owner
      ,a.table_name
      ,'MDSYS.SDO_TOPO'
      ,'MDSYS.SDO_TOPO'
      ,'FEATURE CLASS'
      ,NULL
      ,NULL
      ,NULL
      BULK COLLECT INTO ary_internal_list
      FROM
      all_tab_columns a
      WHERE
          a.owner = str_owner
      AND a.data_type_owner IN ('MDSYS','PUBLIC')
      AND a.data_type = 'SDO_TOPO_GEOMETRY'
      GROUP BY
       a.owner
      ,a.table_name
      ORDER BY
       a.owner
      ,a.table_name;

      ary_sdo_geometry := c2t(ary_internal_list);

      --------------------------------------------------------------------------
      -- Step 90
      -- harvest any MDSYS.SDO_GEOMETRY spatial tables but skip sdo items
      -- supporting more complex types like georaster and topology
      --------------------------------------------------------------------------
      SELECT
       a.owner
      ,a.table_name
      ,'MDSYS.' || MAX(a.data_type)
      ,'MDSYS.' || MAX(a.data_type)
      ,'FEATURE CLASS'
      ,NULL
      ,NULL
      ,NULL
      BULK COLLECT INTO ary_internal_list
      FROM
      all_tab_columns a
      WHERE
          a.owner = str_owner
      AND a.data_type_owner IN ('MDSYS','PUBLIC')
      AND a.data_type IN ('SDO_GEOMETRY','ST_GEOMETRY')
      -- This is to remove any topo geometry feature classes that might have sdo too
      AND a.table_name NOT IN (SELECT table_name FROM TABLE(ary_sdo_geometry))
      AND a.table_name NOT IN (SELECT table_name FROM TABLE(ary_georasters))
      AND a.table_name NOT IN (SELECT table_name FROM TABLE(ary_rasters))
      AND a.table_name NOT IN (SELECT table_name FROM TABLE(ary_topologies))
      AND a.table_name NOT IN (SELECT table_name FROM TABLE(ary_ndms))
      GROUP BY
       a.owner
      ,a.table_name
      ORDER BY
       a.owner
      ,a.table_name;

      append_ary(
          ary_sdo_geometry
         ,c2t(ary_internal_list)
      );

      --------------------------------------------------------------------------
      -- Step 100
      -- harvest any MDSYS.SDO_GEOMETRY domain tables but segregate indexes
      -- supporting more complex items such as georasters and topologies
      --------------------------------------------------------------------------
      SELECT
       b.sdo_index_owner
      ,b.sdo_index_table
      ,'MDSYS.SPATIAL_INDEX'
      ,CASE
       WHEN c.category_type2 IS NULL
       THEN
          'MDSYS.SDO_GEOMETRY'
       ELSE
          c.category_type2
       END
      ,'FEATURE CLASS'
      ,a.table_owner
      ,a.table_name
      ,NULL
      BULK COLLECT INTO ary_internal_list
      FROM
      all_indexes a
      JOIN
      all_sdo_index_metadata b
      ON
      a.index_name = b.sdo_index_name
      LEFT JOIN
      TABLE(ary_sdo_geometry) c
      ON
      a.table_name = c.table_name
      WHERE
          a.owner = str_owner
      AND (a.table_owner,a.table_name) NOT IN (SELECT table_owner,table_name FROM TABLE(ary_georasters))
      AND (a.table_owner,a.table_name) NOT IN (SELECT table_owner,table_name FROM TABLE(ary_rasters))
      AND (a.table_owner,a.table_name) NOT IN (SELECT table_owner,table_name FROM TABLE(ary_topologies))
      AND (a.table_owner,a.table_name) NOT IN (SELECT table_owner,table_name FROM TABLE(ary_ndms))
      ORDER BY
       b.sdo_index_owner
      ,b.sdo_index_table;

      ary_sdo_domain := c2t(ary_internal_list);

      SELECT
       b.sdo_index_owner
      ,b.sdo_index_table
      ,'MDSYS.SPATIAL_INDEX'
      ,'MDSYS.SDO_GEORASTER'
      ,'RASTER'
      ,a.table_owner
      ,a.table_name
      ,NULL
      BULK COLLECT INTO ary_internal_list
      FROM
      all_indexes a
      JOIN
      all_sdo_index_metadata b
      ON
      a.index_name = b.sdo_index_name
      WHERE
          a.owner = str_owner
      AND ( (a.table_owner,a.table_name) IN (SELECT table_owner,table_name FROM TABLE(ary_georasters))
          OR (a.table_owner,a.table_name) IN (SELECT table_owner,table_name FROM TABLE(ary_rasters))
      )
      ORDER BY
       b.sdo_index_owner
      ,b.sdo_index_table;

      append_ary(
          ary_sdo_domain
         ,c2t(ary_internal_list)
      );

      SELECT
       b.sdo_index_owner
      ,b.sdo_index_table
      ,'MDSYS.SPATIAL_INDEX'
      ,'MDSYS.SDO_TOPO'
      ,'TOPOLOGY'
      ,c.parent_owner
      ,c.parent_table_name
      ,NULL
      BULK COLLECT INTO ary_internal_list
      FROM
      all_indexes a
      JOIN
      all_sdo_index_metadata b
      ON
      a.index_name = b.sdo_index_name
      JOIN
      TABLE(ary_topologies) c
      ON
      a.table_name = c.table_name
      WHERE
      a.owner = str_owner
      ORDER BY
       b.sdo_index_owner
      ,b.sdo_index_table;

      append_ary(
          ary_sdo_domain
         ,c2t(ary_internal_list)
      );

      SELECT
       b.sdo_index_owner
      ,b.sdo_index_table
      ,'MDSYS.SPATIAL_INDEX'
      ,'MDSYS.SDO_NET'
      ,'NETWORK'
      ,c.parent_owner
      ,c.parent_table_name
      ,NULL
      BULK COLLECT INTO ary_internal_list
      FROM
      all_indexes a
      JOIN
      all_sdo_index_metadata b
      ON
      a.index_name = b.sdo_index_name
      JOIN
      TABLE(ary_ndms) c
      ON
      a.table_name = c.table_name
      WHERE
      a.owner = str_owner
      ORDER BY
       b.sdo_index_owner
      ,b.sdo_index_table;

      append_ary(
          ary_sdo_domain
         ,c2t(ary_internal_list)
      );

      ary_tmp_load := ary_sdo_domain;
      int_index := ary_sdo_domain.COUNT + 1;
      ary_sdo_domain.EXTEND(ary_tmp_load.COUNT);

      FOR i IN 1 .. ary_tmp_load.COUNT
      LOOP
         ary_sdo_domain(int_index) := ary_tmp_load(i);
         ary_sdo_domain(int_index).table_name := REPLACE(
             ary_sdo_domain(int_index).table_name
            ,'MDRT'
            ,'MDXT'
         );
         int_index := int_index + 1;

      END LOOP;

      --------------------------------------------------------------------------
      -- Step 100
      -- Check for CTX domain index tables
      --------------------------------------------------------------------------
      IF num_ctx = 1
      THEN
         str_sql := 'WITH ctxs AS ( '
                 || '   SELECT '
                 || '    a.idx_name '
                 || '   ,a.idx_table_owner '
                 || '   ,a.idx_table '
                 || '   FROM ';

         IF str_user_segments = 'TRUE'
         THEN
            str_sql := str_sql || '   ctxsys.ctx_user_indexes a ';

         ELSE
            str_sql := str_sql || '   ctxsys.ctx_indexes a ';

         END IF;

         str_sql := str_sql
                 || '   WHERE '
                 || '   a.idx_table_owner = :p01 '
                 || ') '
                 || 'SELECT '
                 || ' a.owner '
                 || ',a.table_name '
                 || ',a.category_type1 '
                 || ',a.category_type2 '
                 || ',a.category_type3 '
                 || ',a.parent_owner '
                 || ',a.parent_table_name '
                 || ',NULL '
                 || 'FROM ( '
                 || '   SELECT '
                 || '    aa.idx_table_owner AS owner '
                 || '   ,aa.idx_table       AS table_name '
                 || '   ,''TABLE''          AS category_type1 '
                 || '   ,''TABLE''          AS category_type2 '
                 || '   ,''ORACLE TEXT''    AS category_type3 '
                 || '   ,aa.idx_table_owner AS parent_owner '
                 || '   ,aa.idx_table       AS parent_table_name '
                 || '   FROM '
                 || '   ctxs aa '
                 || '   UNION ALL '
                 || '   SELECT '
                 || '    bb.idx_table_owner '
                 || '   ,''DR$'' || bb.idx_name || ''$I'' '
                 || '   ,''CTXSYS.CONTEXT'' '
                 || '   ,''CTXSYS.CONTEXT'' '
                 || '   ,''ORACLE TEXT'' '
                 || '   ,bb.idx_table_owner '
                 || '   ,bb.idx_table '
                 || '   FROM '
                 || '   ctxs bb '
                 || '   UNION ALL '
                 || '   SELECT '
                 || '    cc.idx_table_owner '
                 || '   ,''DR$'' || cc.idx_name || ''$K'' '
                 || '   ,''CTXSYS.CONTEXT'' '
                 || '   ,''CTXSYS.CONTEXT'' '
                 || '   ,''ORACLE TEXT'' '
                 || '   ,cc.idx_table_owner '
                 || '   ,cc.idx_table '
                 || '   FROM '
                 || '   ctxs cc '
                 || '   UNION ALL '
                 || '   SELECT '
                 || '    dd.idx_table_owner '
                 || '   ,''DR$'' || dd.idx_name || ''$N'' '
                 || '   ,''CTXSYS.CONTEXT'' '
                 || '   ,''CTXSYS.CONTEXT'' '
                 || '   ,''ORACLE TEXT'' '
                 || '   ,dd.idx_table_owner '
                 || '   ,dd.idx_table '
                 || '   FROM '
                 || '   ctxs dd '
                 || '   UNION ALL '
                 || '   SELECT '
                 || '    ee.idx_table_owner '
                 || '   ,''DR$'' || ee.idx_name || ''$R'' '
                 || '   ,''CTXSYS.CONTEXT'' '
                 || '   ,''CTXSYS.CONTEXT'' '
                 || '   ,''ORACLE TEXT'' '
                 || '   ,ee.idx_table_owner '
                 || '   ,ee.idx_table '
                 || '   FROM '
                 || '   ctxs ee '
                 || ') a ';

         EXECUTE IMMEDIATE str_sql
         BULK COLLECT INTO ary_internal_list
         USING str_owner;

         ary_ctxs := c2t(ary_internal_list);

      END IF;

      --------------------------------------------------------------------------
      -- Step 110
      -- Now categorize each table
      --------------------------------------------------------------------------
      WITH all_tables_pool AS (
         SELECT
          a.owner
         ,a.table_name
         FROM
         all_all_tables a
         WHERE
         a.owner = str_owner
      )
      SELECT
       a.owner
      ,a.table_name
      ,a.category_type1
      ,a.category_type2
      ,a.category_type3
      ,a.parent_owner
      ,a.parent_table_name
      ,NULL
      BULK COLLECT INTO ary_internal_list
      FROM (
         -- Start with nonspatial tables
         SELECT
          aa.owner
         ,aa.table_name
         ,'TABLE'   AS category_type1
         ,'TABLE'   AS category_type2
         ,'TABLE'   AS category_type3
         ,aa.owner      AS parent_owner
         ,aa.table_name AS parent_table_name
         ,NULL AS item_size_bytes
         FROM
         all_tables_pool aa
         WHERE
             aa.table_name NOT IN (SELECT table_name FROM TABLE(ary_georasters))
         AND aa.table_name NOT IN (SELECT table_name FROM TABLE(ary_rasters))
         AND aa.table_name NOT IN (SELECT table_name FROM TABLE(ary_sde_geometry))
         AND aa.table_name NOT IN (SELECT table_name FROM TABLE(ary_sde_domain))
         AND aa.table_name NOT IN (SELECT table_name FROM TABLE(ary_sdo_geometry))
         AND aa.table_name NOT IN (SELECT table_name FROM TABLE(ary_sdo_domain))
         AND aa.table_name NOT IN (SELECT table_name FROM TABLE(ary_topologies))
         AND aa.table_name NOT IN (SELECT table_name FROM TABLE(ary_ndms))
         AND aa.table_name NOT IN (SELECT table_name FROM TABLE(ary_ctxs))
         -----------------------------------------------------------------------
         -- Georaster Tables
         UNION ALL
         SELECT
          bb.owner
         ,bb.table_name
         ,'MDSYS.SDO_GEORASTER'
         ,'MDSYS.SDO_GEORASTER'
         ,'RASTER'
         ,bb.owner
         ,bb.table_name
         ,NULL
         FROM
         all_tables_pool bb
         JOIN
         TABLE(ary_georasters) cc
         ON
         bb.table_name = cc.table_name
         -----------------------------------------------------------------------
         -- Raster Tables
         UNION ALL
         SELECT
          dd.owner
         ,dd.table_name
         ,'MDSYS.SDO_RASTER'
         ,'MDSYS.SDO_GEORASTER'
         ,'RASTER'
         ,ee.parent_owner
         ,ee.parent_table_name
         ,NULL
         FROM
         all_tables_pool dd
         JOIN
         TABLE(ary_rasters) ee
         ON
         dd.table_name = ee.table_name
         -----------------------------------------------------------------------
         -- Topology Tables
         UNION ALL
         SELECT
          ff.owner
         ,ff.table_name
         ,gg.category_type1
         ,gg.category_type2
         ,gg.category_type3
         ,gg.parent_owner
         ,gg.parent_table_name
         ,NULL
         FROM
         all_tables_pool ff
         JOIN
         TABLE(ary_topologies) gg
         ON
         ff.table_name = gg.table_name
         -----------------------------------------------------------------------
         -- Network Tables
         UNION ALL
         SELECT
          hh.owner
         ,hh.table_name
         ,ii.category_type1
         ,ii.category_type2
         ,ii.category_type3
         ,ii.parent_owner
         ,ii.parent_table_name
         ,NULL
         FROM
         all_tables_pool hh
         JOIN
         TABLE(ary_ndms) ii
         ON
         hh.table_name = ii.table_name
         -----------------------------------------------------------------------
         -- SDE Geometry Tables
         UNION ALL
         SELECT
          jj.owner
         ,jj.table_name
         ,kk.category_type1
         ,kk.category_type2
         ,kk.category_type3
         ,jj.owner
         ,jj.table_name
         ,NULL
         FROM
         all_tables_pool jj
         JOIN
         TABLE(ary_sde_geometry) kk
         ON
         jj.table_name = kk.table_name
         -----------------------------------------------------------------------
         -- SDE Domain Tables
         UNION ALL
         SELECT
          ll.owner
         ,ll.table_name
         ,mm.category_type1
         ,mm.category_type2
         ,mm.category_type3
         ,mm.parent_owner
         ,mm.parent_table_name
         ,NULL
         FROM
         all_tables_pool ll
         JOIN
         TABLE(ary_sde_domain) mm
         ON
         ll.table_name = mm.table_name
         -----------------------------------------------------------------------
         -- SDO Geometry Tables
         UNION ALL
         SELECT
          nn.owner
         ,nn.table_name
         ,oo.category_type1
         ,oo.category_type2
         ,oo.category_type3
         ,nn.owner
         ,nn.table_name
         ,NULL
         FROM
         all_tables_pool nn
         JOIN
         TABLE(ary_sdo_geometry) oo
         ON
         nn.table_name = oo.table_name
         -----------------------------------------------------------------------
         -- SDO Domain Tables
         UNION ALL
         SELECT
          pp.owner
         ,pp.table_name
         ,qq.category_type1
         ,qq.category_type2
         ,qq.category_type3
         ,qq.parent_owner
         ,qq.parent_table_name
         ,NULL
         FROM
         all_tables_pool pp
         JOIN
         TABLE(ary_sdo_domain) qq
         ON
         pp.table_name = qq.table_name
         -----------------------------------------------------------------------
         -- CTX Domain Tables
         UNION ALL
         SELECT
          rr.owner
         ,rr.table_name
         ,ss.category_type1
         ,ss.category_type2
         ,ss.category_type3
         ,ss.parent_owner
         ,ss.parent_table_name
         ,NULL
         FROM
         all_tables_pool rr
         JOIN
         TABLE(ary_ctxs) ss
         ON
         rr.table_name = ss.table_name
      ) a
      ORDER BY
       a.parent_owner
      ,a.parent_table_name
      ,CASE
       WHEN a.parent_table_name = a.table_name
       THEN
          '0'
       ELSE
          '1' || category_type1
       END;

      --------------------------------------------------------------------------
      -- Step 130
      -- Output the results
      --------------------------------------------------------------------------
      FOR i IN 1 .. ary_internal_list.COUNT
      LOOP
         ary_internal_list(i).item_size_bytes := get_simple_table_size(
             p_table_owner   => ary_internal_list(i).owner
            ,p_table_name    => ary_internal_list(i).table_name
            ,p_user_segments => str_user_segments
         );

      END LOOP;

      ary_tables := c2t(ary_internal_list);

      --------------------------------------------------------------------------
      -- Step 130
      -- Output the results
      --------------------------------------------------------------------------
      FOR i IN 1 .. ary_tables.COUNT
      LOOP
         PIPE ROW(ary_tables(i));

      END LOOP;

   END schema_summary;

END dz_dba_sizer;
/


--*************************--
PROMPT DZ_DBA_TEST.pks;

CREATE OR REPLACE PACKAGE dz_dba_test
AUTHID DEFINER
AS

   C_TFS_CHANGESET CONSTANT NUMBER := 8194;
   C_JENKINS_JOBNM CONSTANT VARCHAR2(255 Char) := 'NULL';
   C_JENKINS_BUILD CONSTANT NUMBER := 11;
   C_JENKINS_BLDID CONSTANT VARCHAR2(255 Char) := 'NULL';
   
   C_PREREQUISITES CONSTANT MDSYS.SDO_STRING2_ARRAY := MDSYS.SDO_STRING2_ARRAY(
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION prerequisites
   RETURN NUMBER;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION version
   RETURN VARCHAR2;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION inmemory_test
   RETURN NUMBER;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION scratch_test
   RETURN NUMBER;
      
END dz_dba_test;
/

GRANT EXECUTE ON dz_dba_test TO public;


--*************************--
PROMPT DZ_DBA_TEST.pkb;

CREATE OR REPLACE PACKAGE BODY dz_dba_test
AS

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION prerequisites
   RETURN NUMBER
   AS
      num_check NUMBER;
      
   BEGIN
      
      FOR i IN 1 .. C_PREREQUISITES.COUNT
      LOOP
         SELECT 
         COUNT(*)
         INTO num_check
         FROM 
         user_objects a
         WHERE 
             a.object_name = C_PREREQUISITES(i) || '_TEST'
         AND a.object_type = 'PACKAGE';
         
         IF num_check <> 1
         THEN
            RETURN 1;
         
         END IF;
      
      END LOOP;
      
      RETURN 0;
   
   END prerequisites;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION version
   RETURN VARCHAR2
   AS
   BEGIN
      RETURN '{"TFS":' || C_TFS_CHANGESET || ','
      || '"JOBN":"' || C_JENKINS_JOBNM || '",'   
      || '"BUILD":' || C_JENKINS_BUILD || ','
      || '"BUILDID":"' || C_JENKINS_BLDID || '"}';
      
   END version;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION inmemory_test
   RETURN NUMBER
   AS
   BEGIN
      RETURN 0;
      
   END inmemory_test;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION scratch_test
   RETURN NUMBER
   AS
   BEGIN
      RETURN 0;
      
   END scratch_test;

END dz_dba_test;
/


--*************************--
PROMPT sqlplus_footer.sql;


SHOW ERROR;

DECLARE
   l_num_errors PLS_INTEGER;

BEGIN

   SELECT
   COUNT(*)
   INTO l_num_errors
   FROM
   user_errors a
   WHERE
   a.name LIKE 'DZ_DBA%';

   IF l_num_errors <> 0
   THEN
      RAISE_APPLICATION_ERROR(-20001,'COMPILE ERROR');

   END IF;

   l_num_errors := DZ_DBA_TEST.inmemory_test();

   IF l_num_errors <> 0
   THEN
      RAISE_APPLICATION_ERROR(-20001,'INMEMORY TEST ERROR');

   END IF;

END;
/

EXIT;


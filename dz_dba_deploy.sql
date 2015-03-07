
--*************************--
PROMPT sqlplus_header.sql;

WHENEVER SQLERROR EXIT -99;
WHENEVER OSERROR  EXIT -98;
SET DEFINE OFF;


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
            all_tables aa
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
            all_tables aa
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
     
   - Build ID: 17
   - TFS Change Set: 5209
   
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
PROMPT DZ_DBA_TEST.pks;

CREATE OR REPLACE PACKAGE dz_dba_test
AUTHID DEFINER
AS

   C_TFS_CHANGESET CONSTANT NUMBER := 5209;
   C_JENKINS_JOBNM CONSTANT VARCHAR2(255) := 'BUILD-DZ_DBA';
   C_JENKINS_BUILD CONSTANT NUMBER := 17;
   C_JENKINS_BLDID CONSTANT VARCHAR2(255) := '17';
   
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


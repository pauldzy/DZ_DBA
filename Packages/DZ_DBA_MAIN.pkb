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

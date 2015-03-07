CREATE OR REPLACE PACKAGE BODY dz_dba_sizer
AS

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_table_size(
       p_table_owner        IN  VARCHAR2 DEFAULT NULL
      ,p_table_name         IN  VARCHAR2      
   ) RETURN NUMBER
   AS
      str_table_owner  VARCHAR2(30 Char) := p_table_owner;
      num_table_size   NUMBER := 0;
      num_check        NUMBER := 0;
      ary_owners       MDSYS.SDO_STRING2_ARRAY := MDSYS.SDO_STRING2_ARRAY();
      ary_names        MDSYS.SDO_STRING2_ARRAY := MDSYS.SDO_STRING2_ARRAY();
            
   BEGIN
   
      IF str_table_owner IS NULL
      THEN
         str_table_owner := USER;
      
      END IF;
      
      SELECT
      COUNT(*)
      INTO
      num_check
      FROM
      all_tables a
      WHERE
          a.owner = str_table_owner
      AND a.table_name = p_table_name;
      
      IF num_check <> 1
      THEN
          RAISE_APPLICATION_ERROR(-20001,'table not found');
          
      END IF;
      
      -- First get table size alone
      num_table_size := num_table_size + get_object_size(
          p_segment_owner => str_table_owner
         ,p_segment_name  => p_table_name     
      );
      
      -- Second, get the table LOBs
      num_table_size := num_table_size + get_table_lob_size(
          p_table_owner => str_table_owner
         ,p_table_name  => p_table_name     
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
                p_table_owner => ary_owners(i)
               ,p_table_name  => ary_names(i)    
            );
            
         END LOOP;
         
      END IF;
      
      RETURN num_table_size;
   
   END get_table_size;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_object_size(
       p_segment_owner      IN  VARCHAR2 DEFAULT NULL
      ,p_segment_name       IN  VARCHAR2      
   ) RETURN NUMBER
   AS
      str_segment_owner   VARCHAR2(30 Char) := p_segment_owner;
      str_iot_type        VARCHAR2(255 Char);
      str_owner           VARCHAR2(30 Char);
      str_index_name      VARCHAR2(30 Char);
      num_bytes           NUMBER;
      str_tablespace_name VARCHAR2(30 Char);
      str_segment_type    VARCHAR2(255 Char);
      num_rows            NUMBER;
      
   BEGIN 
   
      IF str_segment_owner IS NULL
      THEN
         str_segment_owner := USER;
         
      END IF;
      
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
         all_tables a
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
         dba_segments a
         LEFT JOIN
         all_tables b
         ON
             a.segment_name = b.table_name
         AND a.owner = b.owner
         WHERE
             a.owner = str_segment_owner
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
      
      IF str_domain_index_owner IS NULL
      THEN
         str_domain_index_owner := USER;
         
      END IF;
      
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
      
      IF str_ityp_owner = 'MDSYS'
      AND str_ityp_name = 'SPATIAL_INDEX'
      THEN
         str_sql := 'SELECT '
                 || 'a.sdo_index_owner, '
                 || 'a.sdo_index_table '
                 || 'FROM '
                 || 'mdsys.sdo_index_metadata_table a '
                 || 'WHERE '
                 || '    a.sdo_index_owner = :p01 '
                 || 'AND a.sdo_index_name = :p02 ';
                 
         EXECUTE IMMEDIATE str_sql
         INTO
          str_spidx_owner
         ,str_spidx_name
         USING
          str_owner
         ,str_index_name;
         
         num_size := get_table_size(
             p_table_owner => str_spidx_owner
            ,p_table_name  => str_spidx_name
         );
         
         -- Account for new MDXT domain tables
         str_mdxt_name := REPLACE(
             str_spidx_name
            ,'MDRT'
            ,'MDXT'
         );
         
         IF dz_dba_util.table_exists(
             p_owner      => str_spidx_owner
            ,p_table_name => str_mdxt_name
         ) = 'TRUE'
         THEN
            num_size := num_size + get_table_size(
                p_table_owner => str_spidx_owner
               ,p_table_name  => str_mdxt_name
            );
         
         END IF;
         
         RETURN num_size;      
                 
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
         
         RETURN get_table_size(
             p_table_owner => str_table_owner
            ,p_table_name  => 'S' || TO_CHAR(num_sde_geom_id) || '$_IX1'
         ) + get_table_size(
             p_table_owner => str_table_owner
            ,p_table_name  => 'S' || TO_CHAR(num_sde_geom_id) || '$_IX2'
         );
      
      ELSIF str_ityp_owner = 'CTXSYS'
      AND str_ityp_name = 'CONTEXT'
      THEN
         str_sql := 'SELECT '
                 || 'a.idx_name '
                 || 'FROM '
                 || 'ctxsys.ctx_indexes a '
                 || 'WHERE '
                 || '    a.idx_table_owner = :p01 '
                 || 'AND a.idx_table= :p02 ';
                 
         EXECUTE IMMEDIATE str_sql
         INTO
         str_ctx_name
         USING
          str_table_owner
         ,str_table_name;
         
         RETURN get_table_size(
             p_table_owner => str_table_owner
            ,p_table_name  => 'DR$' || str_ctx_name || '$I'
         ) + get_table_size(
             p_table_owner => str_table_owner
            ,p_table_name  => 'DR$' || str_ctx_name || '$R'
         );
         
      ELSE
         RAISE_APPLICATION_ERROR(-20001,'unhandled domain index type');
      
      END IF;
      
   END get_domain_index_size;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_table_lob_size(
       p_table_owner        IN  VARCHAR2 DEFAULT NULL
      ,p_table_name         IN  VARCHAR2      
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
         );
         
         num_lob_size := num_lob_size + get_object_size(
             p_segment_owner => p_table_owner
            ,p_segment_name  => ary_lob_indexes(i)
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
      all_tables a
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
         all_tables a
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
   
END dz_dba_sizer;
/

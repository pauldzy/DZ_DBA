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
            a.segment_name = p_segment_name; 
         
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
              || 'AND a.segment_name = :p02 ';
         
       BEGIN
         EXECUTE IMMEDIATE str_sql
         INTO
          num_bytes 
         ,str_tablespace_name 
         ,str_segment_type 
         ,num_rows
         USING
          str_segment_owner
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
             p_table_owner       => str_table_owner
            ,p_table_name        => 'DR$' || str_ctx_name || '$I'
            ,p_return_zero_onerr => 'TRUE'
            ,p_user_segments     => p_user_segments
         ) + get_table_size(
             p_table_owner       => str_table_owner
            ,p_table_name        => 'DR$' || str_ctx_name || '$R'
            ,p_return_zero_onerr => 'TRUE'
            ,p_user_segments     => p_user_segments
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
            ,p_user_segments => p_user_segments
         );
         
         num_lob_size := num_lob_size + get_object_size(
             p_segment_owner => p_table_owner
            ,p_segment_name  => ary_lob_indexes(i)
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
      int_index         NUMBER;
      str_sql           VARCHAR2(4000 Char);
      ary_tables        dz_dba_summary_list := dz_dba_summary_list();
      ary_tmp_load      dz_dba_summary_list := dz_dba_summary_list();
      ary_georasters    dz_dba_summary_list := dz_dba_summary_list();
      ary_rasters       dz_dba_summary_list := dz_dba_summary_list();
      ary_sde_geometry  dz_dba_summary_list := dz_dba_summary_list();
      ary_sde_domain    dz_dba_summary_list := dz_dba_summary_list();
      ary_sdo_geometry  dz_dba_summary_list := dz_dba_summary_list();
      ary_sdo_domain    dz_dba_summary_list := dz_dba_summary_list();
      
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
      
      --------------------------------------------------------------------------
      -- Step 30
      -- First collect any georaster tables
      --------------------------------------------------------------------------  
      SELECT
      dz_dba_summary(
          a.owner
         ,a.table_name
         ,a.column_name
         ,'RASTER'
         ,'RASTER'
         ,NULL
         ,NULL
         ,NULL
      )
      BULK COLLECT INTO ary_georasters
      FROM
      all_tab_columns a
      WHERE 
          a.owner = p_owner
      AND a.data_type_owner IN ('MDSYS','PUBLIC')
      AND a.data_type = 'SDO_GEORASTER'
      ORDER BY
       a.owner
      ,a.table_name
      ,a.column_name;
      
      --------------------------------------------------------------------------
      -- Step 40
      -- Second harvest the names of the raster tables 
      --------------------------------------------------------------------------
      FOR i IN 1 .. ary_georasters.COUNT
      LOOP
         str_sql := 'SELECT '
                 || 'dz_dba_summary( '
                 || '    ''' || ary_georasters(i).owner || ''''
                 || '   ,a.' || ary_georasters(i).category_type1 || '.RASTERDATATABLE '
                 || '   ,''RASTER'' '
                 || '   ,''RASTER'' '
                 || '   ,''RASTER'' '
                 || '   ,''' || ary_georasters(i).owner || ''''
                 || '   ,''' || ary_georasters(i).table_name || ''''
                 || '   ,NULL ' 
                 || ') '
                 || 'FROM '
                 || ary_georasters(i).owner || '.' || ary_georasters(i).table_name || ' a '
                 || 'WHERE '
                 || 'a.' || ary_georasters(i).category_type1 || ' IS NOT NULL ';
             
         EXECUTE IMMEDIATE str_sql
         BULK COLLECT INTO ary_tmp_load;
         
         append_ary(
             ary_rasters
            ,ary_tmp_load
         );
      
      END LOOP;
      
      --------------------------------------------------------------------------
      -- Step 50
      -- harvest any SDE.ST_GEOMETRY domain tables 
      --------------------------------------------------------------------------
      IF num_esri = 1
      THEN
         str_sql := 'SELECT '
                 || 'dz_dba_summary( '
                 || '    a.owner '
                 || '   ,a.table_name '
                 || '   ,''SDE.ST_GEOMETRY'' '
                 || '   ,''SDE.ST_GEOMETRY'' '
                 || '   ,''FEATURE CLASS'' '
                 || '   ,NULL '
                 || '   ,NULL '
                 || '   ,NULL ' 
                 || ') '
                 || 'FROM '
                 || 'sde.st_geometry_columns a '
                 || 'WHERE '
                 || 'a.owner = :p01 ';
         
         EXECUTE IMMEDIATE str_sql 
         BULK COLLECT INTO ary_sde_geometry
         USING str_owner;
      
         str_sql := 'SELECT '
                 || 'dz_dba_summary( '
                 || '    a.owner '
                 || '   ,''S'' || a.geom_id || ''_IDX$'' '
                 || '   ,''SDE.ST_SPATIAL_INDEX'' '
                 || '   ,''SDE.ST_GEOMETRY'' '
                 || '   ,''FEATURE CLASS'' '
                 || '   ,a.owner '
                 || '   ,a.table_name '
                 || '   ,NULL ' 
                 || ') '
                 || 'FROM '
                 || 'sde.st_geometry_columns a '
                 || 'WHERE '
                 || 'a.owner = :p01 ';
         
         EXECUTE IMMEDIATE str_sql 
         BULK COLLECT INTO ary_sde_domain
         USING str_owner;
        
      END IF;
      
      --------------------------------------------------------------------------
      -- Step 60
      -- harvest any MDSYS.SDO_GEOMETRY spatial tables but skip georaster
      --------------------------------------------------------------------------
      SELECT
      dz_dba_summary(
          a.owner
         ,a.table_name
         ,'MDSYS.SDO_GEOMETRY'
         ,'MDSYS.SDO_GEOMETRY'
         ,'FEATURE CLASS'
         ,NULL
         ,NULL
         ,NULL
      )
      BULK COLLECT INTO ary_sdo_geometry
      FROM
      all_tab_columns a
      WHERE
          a.owner = str_owner
      AND a.data_type_owner = 'MDSYS'
      AND a.data_type = 'SDO_GEOMETRY'
      AND a.table_name NOT IN (SELECT table_name FROM TABLE(ary_georasters))
      AND a.table_name NOT IN (SELECT table_name FROM TABLE(ary_rasters))
      GROUP BY
       a.owner
      ,a.table_name
      ORDER BY
       a.owner
      ,a.table_name;
      
      --------------------------------------------------------------------------
      -- Step 70
      -- harvest any MDSYS.SDO_GEOMETRY domain tables 
      --------------------------------------------------------------------------
      SELECT
      dz_dba_summary(
          b.sdo_index_owner
         ,b.sdo_index_table
         ,'MDSYS.SPATIAL_INDEX'
         ,'MDSYS.SDO_GEOMETRY'
         ,'FEATURE CLASS'
         ,a.table_owner
         ,a.table_name
         ,NULL
      )
      BULK COLLECT INTO ary_tmp_load
      FROM
      all_indexes a
      JOIN
      mdsys.sdo_index_metadata_table b
      ON
      a.index_name = b.sdo_index_name
      WHERE
      a.owner = str_owner
      ORDER BY
       b.sdo_index_owner
      ,b.sdo_index_table;
      
      ary_sdo_domain := ary_tmp_load;
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
      -- Step 80
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
      dz_dba_summary(
          a.owner
         ,a.table_name
         ,a.category_type1
         ,a.category_type2
         ,a.category_type3
         ,a.parent_owner
         ,a.parent_table_name
         ,get_simple_table_size(
              p_table_owner   => a.owner
             ,p_table_name    => a.table_name
             ,p_user_segments => str_user_segments   
          )
      )
      BULK COLLECT INTO ary_tables
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
         -- Georaster Tables
         UNION ALL
         SELECT
          bb.owner
         ,bb.table_name
         ,'GEORASTER'
         ,'GEORASTER'
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
         -- Raster Tables
         UNION ALL
         SELECT
          dd.owner
         ,dd.table_name
         ,'RDT'
         ,'GEORASTER'
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
         -- SDE Geometry Tables
         UNION ALL
         SELECT
          ff.owner
         ,ff.table_name
         ,'SDE.ST_GEOMETRY'
         ,'SDE.ST_GEOMETRY'
         ,'FEATURE CLASS'
         ,ff.owner
         ,ff.table_name
         ,NULL
         FROM
         all_tables_pool ff
         JOIN
         TABLE(ary_sde_geometry) gg
         ON
         ff.table_name = gg.table_name
         -- SDE Domain Tables
         UNION ALL
         SELECT
          hh.owner
         ,hh.table_name
         ,'SDE.ST_SPATIAL_INDEX'
         ,'SDE.ST_GEOMETRY'
         ,'FEATURE CLASS'
         ,ii.parent_owner
         ,ii.parent_table_name
         ,NULL
         FROM
         all_tables_pool hh
         JOIN
         TABLE(ary_sde_domain) ii
         ON
         hh.table_name = ii.table_name
         -- SDO Geometry Tables
         UNION ALL
         SELECT
          jj.owner
         ,jj.table_name
         ,'MDSYS.SDO_GEOMETRY'
         ,'MDSYS.SDO_GEOMETRY'
         ,'FEATURE CLASS'
         ,jj.owner
         ,jj.table_name
         ,NULL
         FROM
         all_tables_pool jj
         JOIN
         TABLE(ary_sdo_geometry) kk
         ON
         jj.table_name = kk.table_name
         -- SDO Domain Tables
         UNION ALL
         SELECT
          mm.owner
         ,mm.table_name
         ,'MDSYS.SPATIAL_INDEX'
         ,'MDSYS.SDO_GEOMETRY'
         ,'FEATURE CLASS'
         ,nn.parent_owner
         ,nn.parent_table_name
         ,NULL
         FROM
         all_tables_pool mm
         JOIN
         TABLE(ary_sdo_domain) nn
         ON
         mm.table_name = nn.table_name
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
      -- Step 90
      -- Output the results
      --------------------------------------------------------------------------
      FOR i IN 1 .. ary_tables.COUNT
      LOOP
         PIPE ROW(ary_tables(i));
      
      END LOOP;
      
   END schema_summary;
   
END dz_dba_sizer;
/


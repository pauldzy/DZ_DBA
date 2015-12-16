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


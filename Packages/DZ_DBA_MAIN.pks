CREATE OR REPLACE PACKAGE dz_dba_main 
AUTHID CURRENT_USER
AS
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   /*
   header: DZ_DBA
     
   - Release: %GITRELEASE%
   - Commit Date: %GITCOMMITDATE%
   
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


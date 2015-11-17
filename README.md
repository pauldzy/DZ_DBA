DZ_DBA

PL/SQL code for the summation and reorganization of database objects

This module was created for the purpose of carefully moving about resources from datafile to datafile as the existing OEM tools do not support online movement of tables having domain (e.g. spatial) indexes.  Of course as always just dumping the data via datapump and reimporting is much easier but in this scenario that is not an option.

Thus the move function in the main package may be of limited utility in 2015.  Use as you will.  The functions in the DZ_DBA_SIZER may still be of interest as they allow one to exactly summarize the space in the database used by tables, lob and indexes (including domain indexes).

The function DZ_DBA_MAIN.SCHEMA_SUMMARY may be used to group and summarize the size of spatial resources in a given schema.  To summarize the items in the connected schema, just execute

SELECT * FROM TABLE(DZ_DBA_SIZER.SCHEMA_SUMMARY());

The results will show each table in the schema with the following additional information:
* category_type1 - A basic category explaining the role of the table either as a simple table, a georaster or rdt table, a table of spatial data (SDO_GEOMETRY or SDE.ST_GEOMETRY) or a domain index table.
* category_type2 - The category of the parent object.  For domain index tables this references the type of spatial data the index supports (SDO_GEOMETRY or SDE.ST_GEOMETRY).  Useful for grouping the results.
* category_type3 - A more generic division of a resource into either RASTER, FEATURE CLASS or TABLE categories
* parent_owner - the parent object the resource is a part of.
* parent_table_name - the parent object the resource is part of.
* item_size_bytes - the size in bytes of the resource.

Thus for a very high level look at how resources are allocated in a schema, you might run

SELECT 
 a.category_type3 
,SUM(a.item_size_bytes)/1024/1024/1024 AS total_gb
FROM 
TABLE(DZ_DBA_SIZER.SCHEMA_SUMMARY()) a
GROUP BY
a.category_type3;

For one of my schemas the results would be:
* FEATURE CLASS 52.6527709960937
* RASTER        227.174987792969
* TABLE         12.5747680664062

Using category_type2 could be helpful in separating your resource between Esri and Oracle spatial types while category_type1 will show the details for domain indexes verses tables.  if all you want is list of spatial items and their sizes, then group on the parent_table_name.

Any feedback or improvements are appreciated.

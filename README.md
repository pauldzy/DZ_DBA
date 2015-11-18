<h2>DZ_DBA</h2>

PL/SQL code for the measuring, summation and reorganization of database objects wiht special emphasis on Oracle Spatial components.

This module was originally created for the purpose of carefully measuring and moving about resources from datafile to datafile as the existing OEM tools do not support online movement of tables having domain (e.g. spatial) indexes.  Of course as always just dumping the data via datapump and reimporting is much easier.
<hr/>

<h4>DZ_DBA_MAIN</h4>
The object mover functions in the main package may be of limited utility if you have the ability to dump and reload tables on the database.  But in situations with limited access, they may be helpful.  Use as you will.  

<h4>DZ_DBA_SIZER</h4>
These functions may still be of interest as they allow one to exactly measure and summarize the space in the database used by tables, lob and indexes (including domain indexes) for both tables and datasets of tables (e.g. get the size of a table with an SDO_GEOMETRY column including the size of all lobs and domain index tables).

<h6>get_table_size</h6>

Function to return the size in bytes of a given table as currently stored in the database.  This includes all associated indexes and lob resources including domain tables and specialized datasets such as georaster datasets.

Example:

To retrieve the size of an Oracle Georaster Table including all component RDT tables:
```SQL
SELECT dz_dba_sizer.get_table_size('MY_SCHEMA','MY_GEORASTER') FROM dual;
```

<h6>schema_summary</h6>

Pipelined function to return the tables in a given schema by a somewhat arbitrary three category system grouping together multi-part datasets to allow one to more easiest summarize resource usage in a schema.

At it's most basic, to run a summary the items in the connected schema:
```SQL
SELECT * FROM TABLE(dz_dba_sizer.schema_summary());
```
The results will show each table in the schema with the following additional information:
* category_type1 - A basic category explaining the role of the table either as a simple table, a georaster or rdt table, a table of spatial data (SDO_GEOMETRY or SDE.ST_GEOMETRY) or a domain index table.
* category_type2 - The category of the parent object.  For domain index tables this references the type of spatial data the index supports (SDO_GEOMETRY or SDE.ST_GEOMETRY).  Useful for grouping the results.
* category_type3 - A more generic division of a resource into either RASTER, FEATURE CLASS or TABLE categories
* parent_owner - the parent object the resource is a part of.
* parent_table_name - the parent object the resource is part of.  Note in the case of topologies and network data models this name is the name of the data model and thus does not exist as an actual table in the schema.
* item_size_bytes - the size in bytes of the resource.

Thus for a very high level look at how resources are allocated in a schema, you might run
```SQL
SELECT 
 a.category_type3 
,SUM(a.item_size_bytes)/1024/1024/1024 AS total_gb
FROM 
TABLE(DZ_DBA_SIZER.SCHEMA_SUMMARY()) a
GROUP BY
a.category_type3;
```
Sample results:
```
* FEATURE CLASS 52.6527709960937
* RASTER        227.174987792969
* TABLE         12.5747680664062
```
Using category_type2 could be helpful in separating your resource between Esri and Oracle spatial types while category_type1 will show the details for domain indexes verses tables.  If all you want is list of spatial items and their sizes, then group on the parent_table_name.

<h5>"Datasets"</h5>

The dz_dba_sizer attempts to group together tabular resources into "datasets".  So for example the spatial index domain tables (MDRT and MDXT) that support a spatial index on a business table are grouped together with the business table as "FEATURE CLASS".  In other situations spatial index domain tables are used by spatial indexes are part of a more complex dataset, such as a topology.  So in that case the logic bundles the index domain tables with the higher object under "TOPOLOGY".

As a system this falls apart if users build multiple dataset types on the same business tables.  So in theory you could have a business table representing some kind of region with an SDO_GEOMETRY column of multipoints showing locations of interest, a SDO_GEORASTER column tied to a small land usage raster of the region and a SDO_TOPO_GEOMETRY column tied back to some master topology of the region boundaries.  I don't recommend such an appproach but you can do that.  In that case its not really possible to tease things out into separate categories.  However I am thinking most rational folks keep such things separate for the most part.

Existing Datasets:
* RASTER - Parent is the table containing the column of SDO_GEORASTER. Children are the RDT tables referenced by the georasters and all spatial index domain tables supporting the georaster.
* TOPOLOGY - Parent is the abstract topology name.  Children are the edge, node, face, relation, history and exp tables of the topology along with all supporting spatial index domain tables.  Note that tables using the topology via SDO_TOPO_GEOMETRY are not part of the dataset.  
* NETWORK - Parent is the abstract network name.  Children are the node, link, path, path link, subpath, partition, partition blob, component and node level tables as listed in the network metadata along with all supporting spatial index domain tables.  
* FEATURE CLASS - Parent is the table containing the column of MDSYS.SDO_GEOMETRY, MDSYS.ST_GEOMETRY, SDE.ST_GEOMETRY or MDSYS.SDO_TOPO_GEOMETRY.  Children are the domain index tables supporting the spatial indexes.  The differences in the spatial types used are expressed in type_category2 in the output.
* ORACLE TEXT - Parent is the table containing the CTXSYS.CONTENT index.  Children are I, K, N and R tables of the domain index.
* TABLE - Everything not covered as one of the datasets above is tagged as a "TABLE".

Any feedback or suggestions for improvements are appreciated.

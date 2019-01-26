CREATE OR REPLACE FUNCTION nhdplus_navigation30.create_temp_tables()
RETURNS INTEGER
VOLATILE
AS $BODY$
DECLARE

BEGIN
   
   ----------------------------------------------------------------------------
   -- Step 10
   -- Create tmp_navigation_connections temp table
   ----------------------------------------------------------------------------
   
   IF nhdplus_navigation30.temp_table_exists('tmp_navigation_working30')
   THEN
      TRUNCATE TABLE tmp_navigation_working30;
      
   ELSE
      CREATE TEMPORARY TABLE tmp_navigation_working30(
          comid                       INTEGER
         ,hydrosequence               INTEGER
         ,fmeasure                    NUMERIC
         ,tmeasure                    NUMERIC
         ,lengthkm                    NUMERIC
         ,flowtimeday                 NUMERIC
         ,network_distancekm          NUMERIC
         ,network_flowtimeday         NUMERIC
         ,downhydrosequence           INTEGER
         ,nav_order                   INTEGER
         ,selected                    BOOLEAN
      );

      CREATE UNIQUE INDEX tmp_navigation_working30_pk
      ON tmp_navigation_working30(comid);
      
      CREATE UNIQUE INDEX tmp_navigation_working30_1u
      ON tmp_navigation_working30(hydrosequence);
      
      CREATE INDEX tmp_navigation_working30_01i
      ON tmp_navigation_working30(network_distancekm);
            
      CREATE INDEX tmp_navigation_working30_02i
      ON tmp_navigation_working30(network_flowtimeday);
      
      CREATE INDEX tmp_navigation_working30_03i
      ON tmp_navigation_working30(downhydrosequence);
      
      CREATE INDEX tmp_navigation_working30_04i
      ON tmp_navigation_working30(selected);
      
   END IF;

   ----------------------------------------------------------------------------
   -- Step 20
   -- I guess that went okay
   ----------------------------------------------------------------------------
   RETURN 0;
   
END;
$BODY$ 
LANGUAGE plpgsql;

ALTER FUNCTION nhdplus_navigation30.create_temp_tables() OWNER TO nhdplus_navigation30;

GRANT EXECUTE ON FUNCTION nhdplus_navigation30.create_temp_tables() TO PUBLIC;


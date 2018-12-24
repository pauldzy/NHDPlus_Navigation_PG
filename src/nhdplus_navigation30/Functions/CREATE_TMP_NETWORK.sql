CREATE OR REPLACE FUNCTION nhdplus_navigation30.create_tmp_network()
RETURNS INTEGER
VOLATILE
AS $BODY$
DECLARE

BEGIN
   
   ----------------------------------------------------------------------------
   -- Step 10
   -- Create tmp_navigation_connections temp table
   ----------------------------------------------------------------------------
   
   IF nhdplus_navigation30.temp_table_exists('tmp_network_working30')
   THEN
      TRUNCATE TABLE tmp_network_working30;
      
   ELSE
      CREATE TEMPORARY TABLE tmp_network_working30(
          comid                       INT4
         ,hydrosequence               INT4
         ,fmeasure                    NUMERIC
         ,tmeasure                    NUMERIC
         ,lengthkm                    NUMERIC
         ,flowtimeday                 NUMERIC
         ,network_distancekm          NUMERIC
         ,network_flowtimeday         NUMERIC
         ,fromnode                    INT4
         ,tonode                      INT4
         ,cost                        FLOAT8
      );

      CREATE INDEX tmp_network_working30_01i
      ON tmp_network_working30(comid);
      
      CREATE INDEX tmp_network_working30_02i
      ON tmp_network_working30(hydrosequence);
      
      CREATE INDEX tmp_network_working30_03i
      ON tmp_network_working30(fromnode);
      
      CREATE INDEX tmp_network_working30_04i
      ON tmp_network_working30(tonode);

   END IF;

   ----------------------------------------------------------------------------
   -- Step 20
   -- I guess that went okay
   ----------------------------------------------------------------------------
   RETURN 0;
   
END;
$BODY$ 
LANGUAGE plpgsql;

ALTER FUNCTION nhdplus_navigation30.create_tmp_network() OWNER TO nhdplus_navigation30;

GRANT EXECUTE ON FUNCTION nhdplus_navigation30.create_tmp_network() TO PUBLIC;


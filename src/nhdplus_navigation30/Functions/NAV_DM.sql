CREATE OR REPLACE FUNCTION nhdplus_navigation30.nav_dm(
    IN  obj_start_flowline        nhdplus_navigation30.flowline
   ,IN  num_maximum_distance_km   NUMERIC
   ,IN  num_maximum_flowtime_day  NUMERIC
) RETURNS INTEGER
VOLATILE
AS $BODY$
DECLARE
   
   int_count INTEGER;
   
BEGIN

   ----------------------------------------------------------------------------
   -- Step 10
   -- Return total count of results
   ----------------------------------------------------------------------------
   WITH RECURSIVE dm(
       comid
      ,hydroseq
      ,dnhydroseq
      ,terminalpathid
      ,fmeasure
      ,tmeasure
      ,lengthkm
      ,flowtimeday
      ,network_distancekm
      ,network_flowtimeday
      ,base_pathlength
      ,base_pathtime
      ,nav_order
   )
   AS (
      SELECT
       obj_start_flowline.comid
      ,obj_start_flowline.hydrosequence
      ,obj_start_flowline.downhydrosequence
      ,obj_start_flowline.terminalpathid
      ,obj_start_flowline.fmeasure
      ,obj_start_flowline.out_measure
      ,obj_start_flowline.out_lengthkm
      ,obj_start_flowline.out_flowtimeday
      ,obj_start_flowline.out_lengthkm
      ,obj_start_flowline.out_flowtimeday
      ,obj_start_flowline.pathlengthkm    + obj_start_flowline.out_lengthkm
      ,obj_start_flowline.pathflowtimeday + obj_start_flowline.out_flowtimeday
      ,0 AS nav_order
      UNION
      SELECT
       mq.comid
      ,mq.hydroseq
      ,mq.dnhydroseq
      ,mq.terminalpathid
      ,mq.fmeasure
      ,mq.tmeasure
      ,mq.lengthkm  -- segment lengthkm
      ,mq.travtime
      ,dm.base_pathlength - mq.pathlength
      ,dm.base_pathtime   - mq.pathtime
      ,dm.base_pathlength -- base pathlength
      ,dm.base_pathtime
      ,dm.nav_order + 1 
      FROM
      nhdplus_navigation30.plusflowlinevaa_nav mq
      CROSS JOIN
      dm
      WHERE
          mq.hydroseq       = dm.dnhydroseq
      AND mq.terminalpathid = dm.terminalpathid
      AND (
            num_maximum_distance_km IS NULL
         OR dm.network_distancekm <= num_maximum_distance_km
      )
      AND (
            num_maximum_flowtime_day IS NULL
         OR dm.network_flowtimeday <= num_maximum_flowtime_day
      )
   )
   INSERT INTO tmp_navigation_working30(
       comid
      ,hydrosequence
      ,fmeasure
      ,tmeasure
      ,lengthkm
      ,flowtimeday
      ,network_distancekm
      ,network_flowtimeday
      ,nav_order
   )
   SELECT
    a.comid
   ,a.hydroseq
   ,a.fmeasure
   ,a.tmeasure
   ,a.lengthkm
   ,a.flowtimeday
   ,a.network_distancekm
   ,a.network_flowtimeday
   ,a.nav_order
   FROM
   dm a;
   
   GET DIAGNOSTICS int_count = ROW_COUNT;
   
   ----------------------------------------------------------------------------
   -- Step 20
   -- Return total count of results
   ----------------------------------------------------------------------------
   RETURN int_count;

END;
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION nhdplus_navigation30.nav_dm(
    nhdplus_navigation30.flowline
   ,NUMERIC
   ,NUMERIC   
) OWNER TO nhdplus_navigation30;

GRANT EXECUTE ON FUNCTION nhdplus_navigation30.nav_dm(
    nhdplus_navigation30.flowline
   ,NUMERIC
   ,NUMERIC
)  TO PUBLIC;


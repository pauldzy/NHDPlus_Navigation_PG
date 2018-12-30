CREATE OR REPLACE FUNCTION nhdplus_navigation30.nav_ut_concise(
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
   WITH RECURSIVE ut(
       comid
      ,hydroseq
      ,levelpathid
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
      ,obj_start_flowline.levelpathid
      ,obj_start_flowline.out_measure
      ,obj_start_flowline.tmeasure
      ,obj_start_flowline.out_lengthkm
      ,obj_start_flowline.out_flowtimeday
      ,obj_start_flowline.out_lengthkm
      ,obj_start_flowline.out_flowtimeday
      ,obj_start_flowline.pathlengthkm    + (obj_start_flowline.lengthkm    - obj_start_flowline.out_lengthkm)
      ,obj_start_flowline.pathflowtimeday + (obj_start_flowline.flowtimeday - obj_start_flowline.out_flowtimeday)
      ,0 AS nav_order
      UNION
      SELECT
       mq.comid
      ,mq.hydroseq
      ,mq.levelpathid
      ,mq.fmeasure
      ,mq.tmeasure
      ,mq.lengthkm
      ,mq.travtime
      ,mq.pathlength - ut.base_pathlength + mq.lengthkm
      ,mq.pathtime   - ut.base_pathtime   + mq.travtime
      ,ut.base_pathlength
      ,ut.base_pathtime
      ,ut.nav_order + 1 
      FROM
      nhdplus_navigation30.plusflowlinevaa_nav mq
      CROSS JOIN
      ut
      WHERE
      mq.ary_downstream_hydroseq @> ARRAY[ut.hydroseq]
      AND (
            num_maximum_distance_km IS NULL
         OR mq.pathlength - ut.base_pathlength <= num_maximum_distance_km
      )
      AND (
            num_maximum_flowtime_day IS NULL
         OR mq.pathtime   - ut.base_pathtime   <= num_maximum_flowtime_day
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
   ut a
   ON CONFLICT DO NOTHING;
   
   GET DIAGNOSTICS int_count = ROW_COUNT;
   
   ----------------------------------------------------------------------------
   -- Step 20
   -- Return total count of results
   ----------------------------------------------------------------------------
   RETURN int_count;

END;
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION nhdplus_navigation30.nav_ut_concise(
    nhdplus_navigation30.flowline
   ,NUMERIC
   ,NUMERIC   
) OWNER TO nhdplus_navigation30;

GRANT EXECUTE ON FUNCTION nhdplus_navigation30.nav_ut_concise(
    nhdplus_navigation30.flowline
   ,NUMERIC
   ,NUMERIC
)  TO PUBLIC;


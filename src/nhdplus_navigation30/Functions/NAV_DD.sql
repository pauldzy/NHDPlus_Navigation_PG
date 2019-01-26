CREATE OR REPLACE FUNCTION nhdplus_navigation30.nav_dd(
    IN  obj_start_flowline        nhdplus_navigation30.flowline
   ,IN  num_maximum_distance_km   NUMERIC
   ,IN  num_maximum_flowtime_day  NUMERIC
) RETURNS INTEGER
VOLATILE
AS $BODY$
DECLARE
   
   r                     RECORD;
   int_count             INTEGER;
   int_min_hydrosequence INTEGER;
   int_min_levelpathid   INTEGER;
   
BEGIN

   ----------------------------------------------------------------------------
   -- Step 10
   -- If unbounded then make a single DD run
   ----------------------------------------------------------------------------
   IF  num_maximum_distance_km  IS NULL
   AND num_maximum_flowtime_day IS NULL
   THEN
      int_count = nhdplus_navigation30.nav_dd_calc(
          int_start_hydrosequence  := NULL
         ,int_rec_order            := -1
         ,num_start_distance_km    := NULL
         ,num_start_flowtime_day   := NULL
         ,obj_start_flowline       := obj_start_flowline
         ,num_maximum_distance_km  := NULL
         ,num_maximum_flowtime_day := NULL
         ,int_min_hydrosequence    := NULL
         ,int_min_levelpathid      := NULL
      );
   
   ----------------------------------------------------------------------------
   -- Step 20
   -- If bounded then loop through each 
   ----------------------------------------------------------------------------
   ELSE
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
         ,selected
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
         ,TRUE
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
         ,dm.nav_order + 1000
         ,CASE 
          WHEN num_maximum_distance_km IS NULL
          OR dm.network_distancekm <= num_maximum_distance_km
          THEN
            TRUE
          WHEN num_maximum_flowtime_day IS NULL
          OR dm.network_flowtimeday <= num_maximum_flowtime_day
          THEN
            TRUE
          ELSE
            FALSE
          END AS selected
         FROM
         nhdplus_navigation30.plusflowlinevaa_nav mq
         CROSS JOIN
         dm
         WHERE
             mq.hydroseq       = dm.dnhydroseq
         AND mq.terminalpathid = dm.terminalpathid
         AND (
               num_maximum_distance_km IS NULL
            OR dm.network_distancekm <= num_maximum_distance_km + 300
         )
         AND (
               num_maximum_flowtime_day IS NULL
            OR dm.network_flowtimeday <= num_maximum_flowtime_day + 5
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
         ,downhydrosequence
         ,nav_order
         ,selected
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
      ,a.dnhydroseq
      ,a.nav_order
      ,a.selected
      FROM
      dm a;      
      
      GET DIAGNOSTICS int_count = ROW_COUNT;
      
      SELECT 
       a.hydroseq 
      ,a.levelpathid
      INTO
       int_min_hydrosequence
      ,int_min_levelpathid
      FROM
      nhdplus_navigation30.plusflowlinevaa_nav a
      WHERE
      a.hydroseq = (
         SELECT
         MIN(b.hydrosequence)
         FROM
         tmp_navigation_working30 b
         WHERE
         b.selected IS TRUE
      );
      
      -------------------------------------------------------------------
      -- Extract the divergences off the mainline
      -------------------------------------------------------------------
      FOR r IN 
         SELECT 
          a.hydroseq
         ,MAX(b.network_distancekm)  AS start_distancekm
         ,MAX(b.network_flowtimeday) AS start_flowtimeday
         ,MAX(b.nav_order) AS nav_order
         FROM 
         nhdplus_navigation30.plusflowlinevaa_nav a
         JOIN (
            SELECT
             bb.hydrosequence
            ,bb.downhydrosequence
            ,bb.network_distancekm
            ,bb.network_flowtimeday
            ,bb.nav_order
            FROM
            tmp_navigation_working30 bb
            WHERE
            bb.selected IS TRUE
            UNION ALL
            SELECT
             obj_start_flowline.hydrosequence
            ,obj_start_flowline.downhydrosequence
            ,obj_start_flowline.out_lengthkm
            ,obj_start_flowline.out_flowtimeday
            ,10
         ) b
         ON
             a.ary_upstream_hydroseq @> ARRAY[b.hydrosequence]
         AND a.hydroseq <> b.downhydrosequence
         WHERE
         NOT EXISTS (
            SELECT
            1
            FROM
            tmp_navigation_working30 cc
            WHERE
            cc.hydrosequence = a.hydroseq
         )
         GROUP BY
         a.hydroseq
         ORDER BY
         MAX(b.nav_order)
      
      LOOP
         int_count := int_count + nhdplus_navigation30.nav_dd_calc(
             int_start_hydrosequence  := r.hydroseq
            ,int_rec_order            := r.nav_order
            ,num_start_distance_km    := r.start_distancekm
            ,num_start_flowtime_day   := r.start_flowtimeday
            ,obj_start_flowline       := NULL
            ,num_maximum_distance_km  := num_maximum_distance_km
            ,num_maximum_flowtime_day := num_maximum_flowtime_day
            ,int_min_hydrosequence    := int_min_hydrosequence
            ,int_min_levelpathid      := int_min_levelpathid
         );

      END LOOP;
   
   END IF;
   
   ----------------------------------------------------------------------------
   -- Step 30
   -- Return total count of results
   ----------------------------------------------------------------------------
   RETURN int_count;

END;
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION nhdplus_navigation30.nav_dd(
    nhdplus_navigation30.flowline
   ,NUMERIC
   ,NUMERIC   
) OWNER TO nhdplus_navigation30;

GRANT EXECUTE ON FUNCTION nhdplus_navigation30.nav_dd(
    nhdplus_navigation30.flowline
   ,NUMERIC
   ,NUMERIC
)  TO PUBLIC;


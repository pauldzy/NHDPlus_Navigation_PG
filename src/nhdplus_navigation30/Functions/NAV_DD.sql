CREATE OR REPLACE FUNCTION nhdplus_navigation30.nav_dd(
    IN  obj_start_flowline        nhdplus_navigation30.flowline
   ,IN  num_maximum_distance_km   NUMERIC
   ,IN  num_maximum_flowtime_day  NUMERIC
) RETURNS INTEGER
VOLATILE
AS $BODY$
DECLARE
   
   r         RECORD;
   int_count INTEGER;
   
BEGIN

   ----------------------------------------------------------------------------
   -- Step 10
   -- If unbounded then make a single DD run
   ----------------------------------------------------------------------------
   IF  num_maximum_distance_km  IS NULL
   AND num_maximum_flowtime_day IS NULL
   THEN
      int_count = nhdplus_navigation30.nav_dd_calc(
          pStartHydroSequence := obj_start_flowline.hydrosequence
         ,pRecOrder           := -1
         ,pStartDistanceKm    := obj_start_flowline.out_lengthkm
         ,pStartFlowTimeDay   := obj_start_flowline.out_flowtimeday
         ,pMaxDistanceKm      := NULL
         ,pMaxFlowTimeDay     := NULL
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
         ,dnminorhyd
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
         ,obj_start_flowline.dnminorhydrosequence
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
         ,mq.dnminorhyd
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
         ,dnminorhyd
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
      ,a.dnminorhyd
      ,a.nav_order
      FROM
      dm a;
      
      GET DIAGNOSTICS int_count = ROW_COUNT;
            
      -------------------------------------------------------------------
      -- Extract the divergences off the mainline
      -------------------------------------------------------------------
      FOR r IN 
         SELECT 
          a.comid
         ,a.hydroseq
         ,MAX(b.network_distancekm)  AS start_distancekm
         ,MAX(b.network_flowtimeday) AS start_flowtimeday
         ,MAX(b.nav_order) AS nav_order
         FROM 
         nhdplus_navigation30.plusflowlinevaa_nav a
         JOIN (
            SELECT
             bb.comid
            ,bb.dnminorhyd
            ,bb.network_distancekm
            ,bb.network_flowtimeday
            ,bb.nav_order
            FROM
            tmp_navigation_working30 bb
            UNION ALL
            SELECT
             obj_start_flowline.comid
            ,obj_start_flowline.dnminorhydrosequence
            ,obj_start_flowline.out_lengthkm
            ,obj_start_flowline.out_flowtimeday
            ,10
         ) b
         ON
         a.hydroseq = b.dnminorhyd
         WHERE
             b.dnminorhyd <> 0
         AND NOT EXISTS (
            SELECT
            1
            FROM
            tmp_navigation_working30 cc
            WHERE
            cc.hydrosequence = a.hydroseq
         )
         GROUP BY
          a.comid
         ,a.hydroseq
         ORDER BY
         MAX(b.nav_order)
      
      LOOP
         int_count := int_count + nhdplus_navigation30.nav_dd_calc(
             pStartHydroSequence := r.hydroseq
            ,pRecOrder           := r.nav_order
            ,pStartDistanceKm    := r.start_distancekm
            ,pStartFlowTimeDay   := r.start_flowtimeday
            ,pMaxDistanceKm      := num_maximum_distance_km
            ,pMaxFlowTimeDay     := num_maximum_flowtime_day
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


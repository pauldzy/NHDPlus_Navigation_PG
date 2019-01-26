CREATE OR REPLACE FUNCTION nhdplus_navigation30.nav_ut_extended(
    IN  obj_start_flowline        nhdplus_navigation30.flowline
   ,IN  num_maximum_distance_km   NUMERIC
   ,IN  num_maximum_flowtime_day  NUMERIC
) RETURNS INTEGER
VOLATILE
AS $BODY$
DECLARE
   
   r                        RECORD;
   int_count                INTEGER;
   int_check                INTEGER;
   num_init_baselengthkm    NUMERIC;
   num_init_baseflowtimeday NUMERIC;
   
BEGIN

   num_init_baselengthkm    := obj_start_flowline.pathlengthkm    + (obj_start_flowline.lengthkm    - obj_start_flowline.out_lengthkm);
   num_init_baseflowtimeday := obj_start_flowline.pathflowtimeday + (obj_start_flowline.flowtimeday - obj_start_flowline.out_flowtimeday);
   
   ----------------------------------------------------------------------------
   -- Step 10
   -- Return total count of results
   ----------------------------------------------------------------------------
   WITH RECURSIVE um(
       comid
      ,hydroseq
      ,levelpathid
      ,uphydroseq
      ,divergence
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
      ,obj_start_flowline.uphydrosequence
      ,obj_start_flowline.divergence
      ,obj_start_flowline.out_measure
      ,obj_start_flowline.tmeasure
      ,obj_start_flowline.out_lengthkm
      ,obj_start_flowline.out_flowtimeday
      ,obj_start_flowline.out_lengthkm
      ,obj_start_flowline.out_flowtimeday
      ,num_init_baselengthkm
      ,num_init_baseflowtimeday
      ,0 AS nav_order
      UNION
      SELECT
       mq.comid
      ,mq.hydroseq
      ,mq.levelpathid
      ,mq.uphydroseq
      ,mq.divergence
      ,mq.fmeasure
      ,mq.tmeasure
      ,mq.lengthkm  -- segment lengthkm
      ,mq.travtime
      ,mq.pathlength - um.base_pathlength + mq.lengthkm
      ,mq.pathtime   - um.base_pathtime   + mq.travtime
      ,um.base_pathlength -- base pathlength
      ,um.base_pathtime
      ,um.nav_order + 1000              
      FROM
      nhdplus_navigation30.plusflowlinevaa_nav mq
      CROSS JOIN
      um
      WHERE 
      (
         (
                mq.hydroseq    = um.uphydroseq
            AND mq.levelpathid = um.levelpathid
         )
         OR (
                mq.hydroseq    = um.uphydroseq
            AND um.divergence  = 2
         )
         OR (
                mq.force_main_line IS TRUE
            AND mq.dnhydroseq  = um.hydroseq
         )
      )
      AND (
            num_maximum_distance_km IS NULL
         OR mq.pathlength - um.base_pathlength <= num_maximum_distance_km
      )
      AND (
            num_maximum_flowtime_day IS NULL
         OR mq.pathtime   - um.base_pathtime   <= num_maximum_flowtime_day
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
   ,a.nav_order
   ,TRUE
   FROM
   um a
   ON CONFLICT DO NOTHING;
   
   GET DIAGNOSTICS int_count = ROW_COUNT;
   
   -------------------------------------------------------------------
   -- Extract the divs off the mainline
   -------------------------------------------------------------------
   FOR r IN 
      SELECT 
       a.comid
      ,a.hydroseq
      ,a.levelpathid
      ,a.fmeasure
      ,a.tmeasure
      ,a.lengthkm
      ,a.travtime
      ,b.network_distancekm  + a.lengthkm AS network_distancekm
      ,b.network_flowtimeday + a.travtime AS network_flowtimeday 
      ,b.nav_order
      FROM 
      nhdplus_navigation30.plusflowlinevaa_nav a
      JOIN
      tmp_navigation_working30 b
      ON
      a.ary_downstream_hydroseq @> ARRAY[b.hydrosequence]
      WHERE NOT EXISTS (
         SELECT
         1
         FROM
         tmp_navigation_working30 cc
         WHERE
         cc.hydrosequence = a.hydroseq
      )
   
   LOOP
      
      BEGIN
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
            ,selected
         ) VALUES (
             r.comid
            ,r.hydroseq
            ,r.fmeasure
            ,r.tmeasure
            ,r.lengthkm
            ,r.travtime
            ,r.network_distancekm
            ,r.network_flowtimeday
            ,r.nav_order
            ,TRUE
         );
   
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
             r.comid
            ,r.hydroseq
            ,r.levelpathid
            ,r.fmeasure
            ,r.tmeasure
            ,r.lengthkm
            ,r.travtime
            ,r.lengthkm
            ,r.travtime
            ,num_init_baselengthkm 
            ,num_init_baseflowtimeday
            ,r.nav_order
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
            AND NOT EXISTS (
               SELECT
               1
               FROM
               tmp_navigation_working30 cc
               WHERE
               cc.hydrosequence = mq.hydroseq
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
         ,a.nav_order
         ,TRUE
         FROM
         ut a
         WHERE
         a.comid <> r.comid
         ON CONFLICT DO NOTHING;
         
         -- At some point this should be removed
         GET DIAGNOSTICS int_check = row_count;
         IF int_check > 10000
         THEN
            RAISE WARNING '% %',r.comid,int_check;
            
         END IF;              
         
         int_count := int_count + int_check;
         
      EXCEPTION
         WHEN UNIQUE_VIOLATION 
         THEN
            NULL;

         WHEN OTHERS
         THEN               
            RAISE;
            
      END;

   END LOOP;
   
   ----------------------------------------------------------------------------
   -- Step 20
   -- Return total count of results
   ----------------------------------------------------------------------------
   RETURN int_count;

END;
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION nhdplus_navigation30.nav_ut_extended(
    nhdplus_navigation30.flowline
   ,NUMERIC
   ,NUMERIC   
) OWNER TO nhdplus_navigation30;

GRANT EXECUTE ON FUNCTION nhdplus_navigation30.nav_ut_extended(
    nhdplus_navigation30.flowline
   ,NUMERIC
   ,NUMERIC
)  TO PUBLIC;


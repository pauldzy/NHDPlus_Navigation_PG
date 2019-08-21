CREATE OR REPLACE FUNCTION nhdplus_navigation30.nav_dd(
    IN  obj_start_flowline        nhdplus_navigation30.flowline
   ,IN  num_maximum_distance_km   NUMERIC
   ,IN  num_maximum_flowtime_day  NUMERIC
) RETURNS INTEGER
VOLATILE
AS $BODY$
DECLARE
   
   rec                    RECORD;
   int_collect            INTEGER;
   int_count              INTEGER;
   int_min_hydrosequence  INTEGER;
   int_min_levelpathid    INTEGER;
   num_pathlength_buffer  NUMERIC := 100;
   num_pathtime_buffer    NUMERIC := 10;
   
BEGIN

   ----------------------------------------------------------------------------
   -- Step 10
   -- Run DM first to establish mainline
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
      ,mq.totma
      ,dm.base_pathlength - mq.pathlength
      ,dm.base_pathtime   - mq.pathtimema
      ,dm.base_pathlength -- base pathlength
      ,dm.base_pathtime
      ,dm.nav_order + 10000
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
         OR dm.network_distancekm <= num_maximum_distance_km + num_pathlength_buffer
      )
      AND (
            num_maximum_flowtime_day IS NULL
         OR dm.network_flowtimeday <= num_maximum_flowtime_day + num_pathtime_buffer
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
   
   ----------------------------------------------------------------------------
   -- Step 20
   -- Tag the nav termination flags
   ----------------------------------------------------------------------------
   WITH cte AS ( 
      SELECT
       a.hydrosequence
      ,b.coastal_connection
      FROM
      tmp_navigation_working30 a
      JOIN
      nhdplus_navigation30.plusflowlinevaa_nav b
      ON
      a.hydrosequence = b.hydroseq
      WHERE
          a.selected = TRUE   
      AND a.navtermination_flag IS NULL
   )
   UPDATE tmp_navigation_working30 a
   SET navtermination_flag = CASE
   WHEN a.nav_order = (SELECT MAX(b.nav_order) FROM tmp_navigation_working30 b LIMIT 1)
   THEN
      CASE
      WHEN cte.coastal_connection = 'Y'
      THEN
         3
      ELSE
         1
      END
   ELSE
      0
   END
   FROM cte
   WHERE
   a.hydrosequence = cte.hydrosequence;
   
   ----------------------------------------------------------------------------
   -- Step 30
   -- Extract the divergences off the mainline
   ----------------------------------------------------------------------------
   LOOP
      FOR rec IN 
         SELECT 
          a.comid
         ,a.hydroseq            AS hydrosequence
         ,a.dnhydroseq          AS downhydrosequence
         ,a.terminalpathid 
         ,a.fmeasure
         ,a.tmeasure
         ,a.lengthkm
         ,a.totma               AS flowtimeday
         ,b.network_distancekm  AS base_pathlength
         ,b.network_flowtimeday AS base_pathtime
         ,b.nav_order + 1       AS nav_order
         FROM 
         nhdplus_navigation30.plusflowlinevaa_nav a
         JOIN 
         tmp_navigation_working30 b
         ON
             a.ary_upstream_hydroseq @> ARRAY[b.hydrosequence]
         AND a.hydroseq <> b.downhydrosequence
         WHERE
             b.selected IS TRUE
         AND NOT EXISTS (
            SELECT
            1
            FROM
            tmp_navigation_working30 cc
            WHERE
            cc.hydrosequence = a.hydroseq
         )
         ORDER BY
         a.hydroseq DESC
      
      LOOP
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
             rec.comid
            ,rec.hydrosequence
            ,rec.downhydrosequence
            ,rec.terminalpathid
            ,rec.fmeasure
            ,rec.tmeasure
            ,rec.lengthkm
            ,rec.flowtimeday
            ,rec.base_pathlength  + rec.lengthkm
            ,rec.base_pathtime    + rec.flowtimeday
            ,rec.base_pathlength 
            ,rec.base_pathtime
            ,rec.nav_order
            ,TRUE
            UNION
            SELECT
             mq.comid
            ,mq.hydroseq
            ,mq.dnhydroseq
            ,mq.terminalpathid
            ,mq.fmeasure
            ,mq.tmeasure
            ,mq.lengthkm
            ,mq.totma
            ,dm.network_distancekm  + mq.lengthkm
            ,dm.network_flowtimeday + mq.totma
            ,dm.base_pathlength
            ,dm.base_pathtime
            ,dm.nav_order + 1
            ,TRUE AS selected
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
         dm a
         ON CONFLICT DO NOTHING;         
         
         GET DIAGNOSTICS int_collect = ROW_COUNT;
         int_count := int_count + int_collect;

      END LOOP;
   
      EXIT WHEN NOT FOUND;
   
   END LOOP;
   
   ----------------------------------------------------------------------------
   -- Step 40
   -- Tag the downstream nav termination flags
   ----------------------------------------------------------------------------
   WITH cte AS ( 
      SELECT
       a.hydrosequence
      ,b.ary_downstream_hydroseq
      ,b.coastal_connection
      FROM
      tmp_navigation_working30 a
      JOIN
      nhdplus_navigation30.plusflowlinevaa_nav b
      ON
      a.hydrosequence = b.hydroseq
      WHERE
          a.selected = TRUE   
      AND a.navtermination_flag IS NULL
   )
   UPDATE tmp_navigation_working30 a
   SET navtermination_flag = CASE
   WHEN EXISTS ( SELECT 1 FROM tmp_navigation_working30 d WHERE d.hydrosequence = ANY(cte.ary_downstream_hydroseq) )
   THEN
      0
   ELSE
      CASE
      WHEN cte.coastal_connection = 'Y'
      THEN
         3
      ELSE
         1
      END
   END
   FROM cte
   WHERE
   a.hydrosequence = cte.hydrosequence;
   
   ----------------------------------------------------------------------------
   -- Step 50
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


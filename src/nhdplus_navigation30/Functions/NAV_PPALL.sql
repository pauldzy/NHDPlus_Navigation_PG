CREATE OR REPLACE FUNCTION nhdplus_navigation30.nav_ppall(
    IN  obj_start_flowline        nhdplus_navigation30.flowline
   ,IN  obj_stop_flowline         nhdplus_navigation30.flowline
) RETURNS INTEGER
VOLATILE
AS $BODY$
DECLARE
   rec         RECORD;
   int_count   INTEGER;
   int_check   INTEGER;
   
BEGIN

   ----------------------------------------------------------------------------
   -- Step 10
   -- Create tmp_network_working30 temp table
   ----------------------------------------------------------------------------
   IF nhdplus_navigation30.temp_table_exists('tmp_network_working30d')
   THEN
      TRUNCATE TABLE tmp_network_working30d;
      
   ELSE
      CREATE TEMPORARY TABLE tmp_network_working30d(
          comid                       INT4
         ,hydrosequence               INT4
         ,dnhydroseq                  INTEGER
         ,terminalpathid              INTEGER
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

      CREATE INDEX tmp_network_working30d_01i
      ON tmp_network_working30d(comid);
      
      CREATE INDEX tmp_network_working30d_02i
      ON tmp_network_working30d(hydrosequence);
      
      CREATE INDEX tmp_network_working30d_03i
      ON tmp_network_working30d(fromnode);
      
      CREATE INDEX tmp_network_working30d_04i
      ON tmp_network_working30d(tonode);

   END IF;

   ----------------------------------------------------------------------------
   -- Step 20
   -- Run downstream mainline
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
      ,fromnode
      ,tonode
      ,cost
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
      ,obj_start_flowline.fromnode
      ,obj_start_flowline.tonode
      ,1::FLOAT8
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
      ,mq.fromnode
      ,mq.tonode
      ,1::FLOAT8
      FROM
      nhdplus_navigation30.plusflowlinevaa_nav mq
      CROSS JOIN
      dm
      WHERE
          mq.hydroseq       =  dm.dnhydroseq
      AND mq.terminalpathid =  dm.terminalpathid
      AND mq.hydroseq       >= obj_stop_flowline.hydrosequence
   )
   INSERT INTO tmp_network_working30d(
       comid
      ,hydrosequence
      ,dnhydroseq 
      ,terminalpathid
      ,fmeasure
      ,tmeasure
      ,lengthkm
      ,flowtimeday
      ,network_distancekm
      ,network_flowtimeday
      ,fromnode
      ,tonode
      ,cost
   )
   SELECT
    a.comid
   ,a.hydroseq
   ,a.dnhydroseq
   ,a.terminalpathid
   ,a.fmeasure
   ,a.tmeasure
   ,a.lengthkm
   ,a.flowtimeday
   ,a.network_distancekm
   ,a.network_flowtimeday
   ,a.fromnode
   ,a.tonode
   ,a.cost
   FROM
   dm a;
   
   ----------------------------------------------------------------------------
   -- Step 30
   -- Traverse any divergences
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
         ,a.fromnode
         ,a.tonode
         FROM 
         nhdplus_navigation30.plusflowlinevaa_nav a
         JOIN 
         tmp_network_working30d b
         ON
             a.ary_upstream_hydroseq @> ARRAY[b.hydrosequence]
         AND a.hydroseq <> b.dnhydroseq
         WHERE
         NOT EXISTS (
            SELECT
            1
            FROM
            tmp_network_working30d cc
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
            ,fromnode
            ,tonode
            ,cost
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
            ,rec.fromnode
            ,rec.tonode
            ,100::FLOAT8 AS cost
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
            ,mq.fromnode
            ,mq.tonode
            ,100::FLOAT8 AS cost
            FROM
            nhdplus_navigation30.plusflowlinevaa_nav mq
            CROSS JOIN
            dm
            WHERE
                mq.hydroseq       = dm.dnhydroseq
            AND mq.terminalpathid = dm.terminalpathid
            AND mq.hydroseq       >= obj_stop_flowline.hydrosequence
            AND NOT EXISTS (
               SELECT
               1
               FROM
               tmp_network_working30d cc
               WHERE
               cc.hydrosequence = mq.hydroseq
            )
         )
         INSERT INTO tmp_network_working30d(
             comid
            ,hydrosequence
            ,dnhydroseq 
            ,terminalpathid
            ,fmeasure
            ,tmeasure
            ,lengthkm
            ,flowtimeday
            ,network_distancekm
            ,network_flowtimeday
            ,fromnode
            ,tonode
            ,cost
         )
         SELECT
          a.comid
         ,a.hydroseq
         ,a.dnhydroseq
         ,a.terminalpathid
         ,a.fmeasure
         ,a.tmeasure
         ,a.lengthkm
         ,a.flowtimeday
         ,a.network_distancekm
         ,a.network_flowtimeday
         ,a.fromnode
         ,a.tonode
         ,a.cost
         FROM
         dm a
         ON CONFLICT DO NOTHING;         

      END LOOP;
   
      EXIT WHEN NOT FOUND;
   
   END LOOP;
      
   ----------------------------------------------------------------------------
   -- Step 40
   -- If downstream location not found, then exit
   ----------------------------------------------------------------------------
   SELECT
   COUNT(*)
   INTO int_count
   FROM 
   tmp_network_working30d a
   WHERE
   a.comid = obj_stop_flowline.comid;
   
   IF int_count = 0
   THEN
      RETURN 0;
      
   END IF;
      
   ----------------------------------------------------------------------------
   -- Step 50
   -- Turn around and go upstream
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
       obj_stop_flowline.comid
      ,obj_stop_flowline.hydrosequence
      ,obj_stop_flowline.levelpathid
      ,obj_stop_flowline.out_measure
      ,obj_stop_flowline.tmeasure
      ,obj_stop_flowline.out_lengthkm
      ,obj_stop_flowline.out_flowtimeday
      ,obj_stop_flowline.out_lengthkm
      ,obj_stop_flowline.out_flowtimeday
      ,obj_stop_flowline.pathlengthkm    + (obj_stop_flowline.lengthkm    - obj_stop_flowline.out_lengthkm)
      ,obj_stop_flowline.pathflowtimeday + (obj_stop_flowline.flowtimeday - obj_stop_flowline.out_flowtimeday)
      ,0 AS nav_order
      UNION
      SELECT
       mq.comid
      ,mq.hydroseq
      ,mq.levelpathid
      ,mq.fmeasure
      ,mq.tmeasure
      ,mq.lengthkm
      ,mq.totma
      ,mq.pathlength - ut.base_pathlength + mq.lengthkm
      ,mq.pathtimema - ut.base_pathtime   + mq.totma
      ,ut.base_pathlength
      ,ut.base_pathtime
      ,ut.nav_order + 1 
      FROM 
      nhdplus_navigation30.plusflowlinevaa_nav mq
      CROSS JOIN
      ut
      WHERE
      mq.ary_downstream_hydroseq @> ARRAY[ut.hydroseq]
      AND mq.hydroseq IN (
         SELECT
         b.hydrosequence
         FROM
         tmp_network_working30d b
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
   ON CONFLICT DO NOTHING;
   
   ----------------------------------------------------------------------------
   -- Step 60
   -- Trim the top of the run
   ----------------------------------------------------------------------------
   UPDATE tmp_navigation_working30 a
   SET 
    fmeasure            = obj_start_flowline.fmeasure
   ,tmeasure            = obj_start_flowline.out_measure
   ,lengthkm            = obj_start_flowline.out_lengthkm
   ,flowtimeday         = obj_start_flowline.out_flowtimeday
   ,network_distancekm  = a.network_distancekm  - (a.lengthkm    - obj_start_flowline.out_lengthkm)
   ,network_flowtimeday = a.network_flowtimeday - (a.flowtimeday - obj_start_flowline.out_flowtimeday)
   ,navtermination_flag = 2
   WHERE
   a.hydrosequence = obj_start_flowline.hydrosequence;
   
   ----------------------------------------------------------------------------
   -- Step 60
   -- Return total count of results
   ----------------------------------------------------------------------------
   SELECT 
   COUNT(*) 
   INTO int_count 
   FROM 
   tmp_navigation_working30 a
   WHERE 
   a.selected IS TRUE;
   
   RETURN int_count;

END;
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION nhdplus_navigation30.nav_ppall(
    nhdplus_navigation30.flowline
   ,nhdplus_navigation30.flowline  
) OWNER TO nhdplus_navigation30;

GRANT EXECUTE ON FUNCTION nhdplus_navigation30.nav_ppall(
    nhdplus_navigation30.flowline
   ,nhdplus_navigation30.flowline
)  TO PUBLIC;


CREATE OR REPLACE FUNCTION nhdplus_navigation30.nav_pp(
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
   IF nhdplus_navigation30.temp_table_exists('tmp_network_working30')
   THEN
      TRUNCATE TABLE tmp_network_working30;
      
   ELSE
      CREATE TEMPORARY TABLE tmp_network_working30(
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
   -- Run downstream mainline as most probable solution
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
      ,mq.travtime
      ,dm.base_pathlength - mq.pathlength
      ,dm.base_pathtime   - mq.pathtime   
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
   INSERT INTO tmp_network_working30(
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

   SELECT
   COUNT(*)
   INTO int_count
   FROM 
   tmp_navigation_working30 a
   WHERE
   a.comid = obj_stop_flowline.comid;
   
   ----------------------------------------------------------------------------
   -- Step 30
   -- If found then dump into working30 and exit
   ----------------------------------------------------------------------------
   IF int_count > 0
   THEN
      INSERT INTO tmp_navigation_working30(
          comid
         ,hydrosequence
         ,fmeasure
         ,tmeasure
         ,lengthkm
         ,flowtimeday
         ,network_distancekm
         ,network_flowtimeday
         ,selected
      )
      SELECT
       b.comid
      ,b.hydrosequence
      ,b.fmeasure
      ,b.tmeasure
      ,b.lengthkm
      ,b.flowtimeday
      ,b.network_distancekm
      ,b.network_flowtimeday
      ,TRUE
      FROM
      tmp_network_working30 b;
      
      UPDATE tmp_navigation_working30 a
      SET
       fmeasure            = obj_stop_flowline.out_measure
      ,tmeasure            = obj_stop_flowline.tmeasure
      ,lengthkm            = obj_stop_flowline.out_lengthkm
      ,flowtimeday         = obj_stop_flowline.out_flowtimeday
      ,network_distancekm  = a.network_distancekm  + obj_stop_flowline.out_lengthkm    - a.lengthkm
      ,network_flowtimeday = a.network_flowtimeday + obj_stop_flowline.out_flowtimeday - a.flowtimeday
      WHERE
      a.comid = obj_stop_flowline.comid;
      
   -------------------------------------------------------------------------
   -- Step 40
   -- Otherwise run divergences downstream
   -------------------------------------------------------------------------
   ELSE
   
      LOOP
         FOR rec IN 
            SELECT 
             a.comid
            ,a.hydroseq   AS hydrosequence
            ,a.dnhydroseq AS downhydrosequence
            ,a.terminalpathid 
            ,a.fmeasure
            ,a.tmeasure
            ,a.lengthkm
            ,a.travtime AS flowtimeday
            ,b.network_distancekm  AS base_pathlength
            ,b.network_flowtimeday AS base_pathtime
            ,a.fromnode
            ,a.tonode
            FROM 
            nhdplus_navigation30.plusflowlinevaa_nav a
            JOIN 
            tmp_network_working30 b
            ON
                a.ary_upstream_hydroseq @> ARRAY[b.hydrosequence]
            AND a.hydroseq <> b.dnhydroseq
            WHERE
            NOT EXISTS (
               SELECT
               1
               FROM
               tmp_network_working30 cc
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
               ,mq.travtime
               ,dm.network_distancekm  + mq.lengthkm
               ,dm.network_flowtimeday + mq.travtime
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
                  tmp_network_working30 cc
                  WHERE
                  cc.hydrosequence = mq.hydroseq
               )
            )
            INSERT INTO tmp_network_working30(
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
      
      SELECT
      COUNT(*)
      INTO int_count
      FROM 
      tmp_network_working30 a
      WHERE
      a.comid = obj_stop_flowline.comid;

      IF int_count > 0
      THEN
         -- Remove duplicate flowlines keeping the cheapest cost
         DELETE FROM tmp_network_working30 a
         WHERE a.ctid IN (
            SELECT b.ctid FROM (
               SELECT
                bb.ctid
               ,ROW_NUMBER() OVER (PARTITION BY bb.comid ORDER BY bb.cost ASC) AS rnum
               FROM
               tmp_network_working30 bb
            ) b
            WHERE
            b.rnum > 1
         );
         
         -- Determine dikstra shortest route from start to stop
         WITH dijk AS(
            SELECT
             a.seq
            ,a.id1 AS node
            ,a.id2 AS edge
            ,a.cost
            FROM
            pgr_dijkstra(
                'SELECT comid AS id,fromnode AS source,tonode AS target,cost,-1::FLOAT8 AS reverse_cost FROM tmp_network_working30'
               ,obj_start_flowline.out_node
               ,obj_stop_flowline.out_node
               ,TRUE
               ,TRUE
            ) a
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
            ,selected
         )
         SELECT
          b.comid
         ,b.hydrosequence
         ,b.fmeasure
         ,b.tmeasure
         ,b.lengthkm
         ,b.flowtimeday
         ,b.network_distancekm
         ,b.network_flowtimeday
         ,TRUE
         FROM
         dijk a
         JOIN
         tmp_network_working30 b
         ON
         a.edge = b.comid;
         
         -- Replace the start and stop segments
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
             obj_start_flowline.comid
            ,obj_start_flowline.hydrosequence
            ,obj_start_flowline.fmeasure
            ,obj_start_flowline.out_measure
            ,obj_start_flowline.out_lengthkm
            ,obj_start_flowline.out_flowtimeday
            ,obj_start_flowline.out_lengthkm
            ,obj_start_flowline.out_flowtimeday
            ,0
            ,TRUE
         );
         
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
             obj_stop_flowline.comid
            ,obj_stop_flowline.hydrosequence
            ,obj_stop_flowline.out_measure
            ,obj_stop_flowline.tmeasure
            ,obj_stop_flowline.out_lengthkm
            ,obj_stop_flowline.out_flowtimeday
            ,obj_start_flowline.out_pathlengthkm    - obj_stop_flowline.out_pathlengthkm
            ,obj_start_flowline.out_pathflowtimeday - obj_stop_flowline.out_pathflowtimeday
            ,99999999
            ,TRUE            
         );
         
      END IF;
   
   END IF;
   
   ----------------------------------------------------------------------------
   -- Step 20
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

ALTER FUNCTION nhdplus_navigation30.nav_pp(
    nhdplus_navigation30.flowline
   ,nhdplus_navigation30.flowline  
) OWNER TO nhdplus_navigation30;

GRANT EXECUTE ON FUNCTION nhdplus_navigation30.nav_pp(
    nhdplus_navigation30.flowline
   ,nhdplus_navigation30.flowline
)  TO PUBLIC;


CREATE OR REPLACE FUNCTION nhdplus_navigation30.nav_pp(
    IN  obj_start_flowline        nhdplus_navigation30.flowline
   ,IN  obj_stop_flowline         nhdplus_navigation30.flowline
) RETURNS INTEGER
VOLATILE
AS $BODY$
DECLARE
   
   int_count   INTEGER;
   int_check   INTEGER;
   
BEGIN

   ----------------------------------------------------------------------------
   -- Step 10
   -- Return total count of results
   ----------------------------------------------------------------------------
   WITH RECURSIVE pp(
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
      ,pp.base_pathlength - mq.pathlength
      ,pp.base_pathtime   - mq.pathtime   
      ,pp.base_pathlength -- base pathlength
      ,pp.base_pathtime
      ,pp.nav_order + 1 
      FROM
      nhdplus_navigation30.plusflowlinevaa_nav mq
      CROSS JOIN
      pp
      WHERE
          mq.hydroseq       =  pp.dnhydroseq
      AND mq.terminalpathid =  pp.terminalpathid
      AND mq.hydroseq       >= obj_stop_flowline.hydrosequence
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
   pp a;
   
   SELECT
   COUNT(*)
   INTO int_count
   FROM 
   tmp_navigation_working30 a
   WHERE
   a.comid = obj_stop_flowline.comid;
   
   -------------------------------------------------------------------------
   -- Next try divergences search as less likely
   -------------------------------------------------------------------------
   IF int_count = 0
   THEN
      int_check := nhdplus_navigation30.create_tmp_network();
      
      WITH RECURSIVE ppdd(
          comid
         ,hydroseq
         ,dnhydroseq
         ,dnminorhyd
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
         ,obj_start_flowline.dnminorhydrosequence
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
         ,1::FLOAT8 AS cost
         UNION
         SELECT
          mq.comid
         ,mq.hydroseq
         ,mq.dnhydroseq
         ,mq.dnminorhyd
         ,mq.fmeasure
         ,mq.tmeasure
         ,mq.lengthkm  -- segment lengthkm
         ,mq.travtime
         ,ppdd.base_pathlength - mq.pathlength
         ,ppdd.base_pathtime   - mq.pathtime   
         ,ppdd.base_pathlength -- base pathlength
         ,ppdd.base_pathtime
         ,mq.fromnode
         ,mq.tonode
         ,CASE 
          WHEN mq.hydroseq = ppdd.dnhydroseq
          THEN
            1::FLOAT8
          ELSE
            100::FLOAT8
          END AS cost               
         FROM
         nhdplus_navigation30.plusflowlinevaa_nav mq
         CROSS JOIN
         ppdd
         WHERE
             mq.ary_upstream_hydroseq @> ARRAY[ppdd.hydroseq] 
         AND mq.hydroseq >= obj_stop_flowline.hydrosequence
      )
      INSERT INTO tmp_network_working30(
          comid
         ,hydrosequence
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
      ppdd a;
      
      SELECT
      COUNT(*)
      INTO int_count
      FROM 
      tmp_network_working30 a
      WHERE
      a.comid = obj_stop_flowline.comid;
      
      TRUNCATE TABLE tmp_navigation_working30;

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
   
   ELSE
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


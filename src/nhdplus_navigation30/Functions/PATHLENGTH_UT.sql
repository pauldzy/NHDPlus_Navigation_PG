CREATE OR REPLACE FUNCTION nhdplus_navigation30.pathlength_ut(
    IN  pStartHydroSequence       INTEGER
   ,IN  pStartInitialFMeasure     NUMERIC
   ,IN  pStartInitialTMeasure     NUMERIC
   ,IN  pStartInitialLengthKm     NUMERIC
   ,IN  pStartInitialFlowTimeDay  NUMERIC
   ,IN  pRecOrder                 INTEGER
   ,IN  pMaxDistanceKm            NUMERIC DEFAULT NULL
   ,IN  pMaxFlowTimeDay           NUMERIC DEFAULT NULL
) RETURNS INTEGER
VOLATILE
AS $BODY$
DECLARE
   rec                   RECORD;
   int_universe_count    INTEGER;
   int_updated           INTEGER;
   int_depth             INTEGER;
   int_sanity            INTEGER;
   int_final_counter     INTEGER;
   ary_stack             INTEGER[];
   int_start_comid       INTEGER;
   num_base_pathlength   NUMERIC;
   num_base_pathtime     NUMERIC;
   int_analyze           INTEGER;
   
BEGIN

   ----------------------------------------------------------------------------
   -- Step 10
   -- Create work temp table
   ----------------------------------------------------------------------------
   IF nhdplus_navigation30.temp_table_exists('tmp_ut30_work')
   THEN
      TRUNCATE TABLE tmp_ut30_work;
      
   ELSE
      CREATE TEMPORARY TABLE tmp_ut30_work(
          comid                       INTEGER
         ,hydroseq                    INTEGER
         ,fmeasure                    NUMERIC
         ,tmeasure                    NUMERIC
         ,lengthkm                    NUMERIC
         ,flowtimeday                 NUMERIC
         ,network_distancekm          NUMERIC
         ,network_flowtimeday         NUMERIC
         ,nav_order                   INTEGER
      );
      
      CREATE INDEX tmp_ut30_work_01i
      ON tmp_ut30_work(hydroseq);

   END IF;

   ----------------------------------------------------------------------------
   -- Step 20
   -- Create intermediate temp table
   ----------------------------------------------------------------------------
   IF nhdplus_navigation30.temp_table_exists('tmp_ut30_inter')
   THEN
      TRUNCATE TABLE tmp_ut30_inter;
      
   ELSE
      CREATE TEMPORARY TABLE tmp_ut30_inter(
          comid                       INTEGER
         ,hydroseq                    INTEGER
         ,fmeasure                    NUMERIC
         ,tmeasure                    NUMERIC
         ,lengthkm                    NUMERIC
         ,flowtimeday                 NUMERIC
         ,network_distancekm          NUMERIC
         ,network_flowtimeday         NUMERIC
         ,nav_order                   INTEGER
      );

   END IF;

   ----------------------------------------------------------------------------
   -- Step 30
   -- Load the existing flow hydrosequece
   ----------------------------------------------------------------------------
   SELECT
   ARRAY(
      SELECT
      a.hydrosequence
      FROM
      tmp_navigation_working30 a
   ) INTO ary_stack;

   ----------------------------------------------------------------------------
   -- Step 40
   -- Load the starter record
   ----------------------------------------------------------------------------
   SELECT
    rc.comid
   ,rc.pathlength + (rc.lengthkm - pStartInitialLengthKm)
   ,rc.pathtime   + (rc.travtime - pStartInitialFlowTimeDay)
   INTO
    int_start_comid
   ,num_base_pathlength
   ,num_base_pathtime 
   FROM
   nhdplus.plusflowlinevaa_np21 rc
   WHERE
   rc.hydroseq = pStartHydroSequence;
   
   INSERT INTO tmp_ut30_work(
       comid
      ,hydroseq
      ,fmeasure
      ,tmeasure
      ,lengthkm
      ,flowtimeday
      ,network_distancekm
      ,network_flowtimeday
      ,nav_order
   ) VALUES (
       int_start_comid
      ,pStartHydroSequence
      ,pStartInitialFMeasure
      ,pStartInitialTMeasure
      ,pStartInitialLengthKm
      ,pStartInitialFlowTimeDay
      ,pStartInitialLengthKm
      ,pStartInitialFlowTimeDay
      ,pRecOrder + 1
   );
   
   GET DIAGNOSTICS int_updated = ROW_COUNT;
   
   IF int_updated = 0
   THEN
      RETURN 0;
      
   END IF;
   
   ary_stack := array_append(ary_stack,pStartHydroSequence);
   ANALYZE tmp_ut30_work;
   
   ----------------------------------------------------------------------------
   -- Step 50
   -- Start the loop
   ----------------------------------------------------------------------------
   int_analyze        := 1;
   int_depth          := pRecOrder + 2;
   int_final_counter  := 0;
   int_universe_count := 1;
   int_sanity         := 7500;
   
   WHILE int_universe_count > 0
   AND   int_sanity         > 0
   LOOP
      IF int_universe_count - int_analyze > 1000
      THEN
         ANALYZE tmp_ut30_work;
         
         int_analyze := int_universe_count;
         
      END IF;
      
   ----------------------------------------------------------------------------
   -- Step 40
   -- First process the main lines as we want main line priority
   ----------------------------------------------------------------------------
      FOR rec IN
         SELECT
          mq.comid
         ,mq.hydroseq
         ,mq.fmeasure
         ,mq.tmeasure
         ,mq.lengthkm
         ,mq.travtime AS flowtimeday
         ,mq.pathlength - num_base_pathlength + mq.lengthkm  AS network_distancekm
         ,mq.pathtime   - num_base_pathtime   + mq.travtime  AS network_flowtimeday  
         FROM
         nhdplus.plusflowlinevaa_np21 mq
         JOIN
         tmp_ut30_work ut
         ON
         mq.dnhydroseq = ut.hydroseq
         WHERE (
               pMaxDistanceKm IS NULL
            OR mq.pathlength  <= pMaxDistanceKm + num_base_pathlength
         )
         AND (
               pMaxFlowTimeDay IS NULL
            OR mq.pathtime <= pMaxFlowTimeDay + num_base_pathtime
         )
         AND mq.pathlength <> -9999
         AND mq.fcode <> 56600
         AND NOT mq.hydroseq = ANY(ary_stack)
      LOOP

         IF rec.hydroseq = ANY(ary_stack)
         THEN
            NULL;
            
         ELSE
            ary_stack := array_append(ary_stack,rec.hydroseq);
    
            INSERT INTO tmp_ut30_inter(
                comid
               ,hydroseq
               ,fmeasure
               ,tmeasure
               ,lengthkm
               ,flowtimeday
               ,network_distancekm
               ,network_flowtimeday
               ,nav_order
            ) VALUES (
                rec.comid
               ,rec.hydroseq
               ,rec.fmeasure
               ,rec.tmeasure
               ,rec.lengthkm
               ,rec.flowtimeday
               ,rec.network_distancekm
               ,rec.network_flowtimeday
               ,int_depth
            );
            
         END IF;

      END LOOP;

   ----------------------------------------------------------------------------
   -- Step 50
   -- Process the minor divergences
   ----------------------------------------------------------------------------
      FOR rec IN
         SELECT
          mq.comid
         ,mq.hydroseq
         ,mq.fmeasure
         ,mq.tmeasure
         ,mq.lengthkm
         ,mq.travtime AS flowtimeday
         ,mq.pathlength - num_base_pathlength + mq.lengthkm  AS network_distancekm
         ,mq.pathtime   - num_base_pathtime   + mq.travtime  AS network_flowtimeday  
         FROM
         nhdplus.plusflowlinevaa_np21 mq
         JOIN
         tmp_ut30_work ut
         ON
         mq.dnminorhyd  = ut.hydroseq
         WHERE (
               pMaxDistanceKm IS NULL
            OR mq.pathlength - num_base_pathlength <= pMaxDistanceKm
         )
         AND (
               pMaxFlowTimeDay IS NULL
            OR mq.pathtime - num_base_pathtime <= pMaxFlowTimeDay
         )
         AND mq.pathlength <> -9999
         AND mq.fcode <> 56600
         AND NOT mq.hydroseq = ANY(ary_stack) 
      LOOP

         IF rec.hydroseq = ANY(ary_stack)
         THEN
            NULL;
            
         ELSE
            ary_stack := array_append(ary_stack,rec.hydroseq);

            INSERT INTO tmp_ut30_inter(
                comid
               ,hydroseq
               ,fmeasure
               ,tmeasure
               ,lengthkm
               ,flowtimeday
               ,network_distancekm
               ,network_flowtimeday
               ,nav_order
            ) VALUES (
                rec.comid
               ,rec.hydroseq
               ,rec.fmeasure
               ,rec.tmeasure
               ,rec.lengthkm
               ,rec.flowtimeday
               ,rec.network_distancekm
               ,rec.network_flowtimeday
               ,int_depth
            );
            
         END IF;

      END LOOP;

   ----------------------------------------------------------------------------
   -- Step 60
   -- Unload the work table into results
   ----------------------------------------------------------------------------
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
      tmp_ut30_work a
      ON CONFLICT DO NOTHING;
      
      GET DIAGNOSTICS int_updated = ROW_COUNT;
      int_final_counter := int_final_counter + int_updated;

   ----------------------------------------------------------------------------
   -- Step 70
   -- Empty the work table
   ----------------------------------------------------------------------------
      TRUNCATE TABLE tmp_ut30_work;
      
   ----------------------------------------------------------------------------
   -- Step 80
   -- Move inter into work
   ----------------------------------------------------------------------------
      INSERT INTO tmp_ut30_work
      SELECT * FROM tmp_ut30_inter;

   ----------------------------------------------------------------------------
   -- Step 90
   -- Empty the inter table
   ----------------------------------------------------------------------------
      TRUNCATE TABLE tmp_ut30_inter;
      
   ----------------------------------------------------------------------------
   -- Step 100
   -- Get the count from the work table
   ----------------------------------------------------------------------------
      SELECT COUNT(*) 
      INTO int_universe_count
      FROM tmp_ut30_work; 

   ----------------------------------------------------------------------------
   -- Step 110
   -- Update loop conditions
   ----------------------------------------------------------------------------
      int_depth  := int_depth + 1;
      int_sanity := int_sanity - 1;

   END LOOP;
   
   ----------------------------------------------------------------------------
   -- Step 120
   -- Return total count of results
   ----------------------------------------------------------------------------
   RETURN int_final_counter;

END;
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION nhdplus_navigation30.pathlength_ut(
    INTEGER
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
   ,INTEGER
   ,NUMERIC
   ,NUMERIC
) OWNER TO nhdplus_navigation30;

GRANT EXECUTE ON FUNCTION nhdplus_navigation30.pathlength_ut(
    INTEGER
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
   ,INTEGER
   ,NUMERIC
   ,NUMERIC
)  TO PUBLIC;


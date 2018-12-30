CREATE OR REPLACE FUNCTION nhdplus_navigation30.nav_dd_calc(
    IN  pStartHydroSequence       INTEGER
   ,IN  pRecOrder                 INTEGER
   ,IN  pStartDistanceKm          NUMERIC
   ,IN  pStartFlowTimeDay         NUMERIC
   ,IN  pMaxDistanceKm            NUMERIC DEFAULT NULL
   ,IN  pMaxFlowTimeDay           NUMERIC DEFAULT NULL
) RETURNS INTEGER
VOLATILE
AS $BODY$
DECLARE
   rec                RECORD;
   int_universe_count INTEGER;
   int_updated        INTEGER;
   int_depth          INTEGER;
   int_sanity         INTEGER;
   int_final_counter  INTEGER;
   ary_stack          INTEGER[];
   int_analyze        INTEGER;
   
BEGIN

   ----------------------------------------------------------------------------
   -- Step 10
   -- Create work temp table
   ----------------------------------------------------------------------------
   IF nhdplus_navigation30.temp_table_exists('tmp_dd30_work')
   THEN
      TRUNCATE TABLE tmp_dd30_work;
      
   ELSE
      CREATE TEMPORARY TABLE tmp_dd30_work(
          comid                       INTEGER
         ,hydroseq                    INTEGER
         ,levelpathid                 INTEGER
         ,dnhydroseq                  INTEGER
         ,dnminorhyd                  INTEGER
         ,fmeasure                    NUMERIC
         ,tmeasure                    NUMERIC
         ,lengthkm                    NUMERIC
         ,flowtimeday                 NUMERIC
         ,network_distancekm          NUMERIC
         ,network_flowtimeday         NUMERIC
         ,nav_order                   INTEGER
      );
      
      CREATE INDEX tmp_dd30_work_01i
      ON tmp_dd30_work(hydroseq);
      
      CREATE INDEX tmp_dd30_work_02i
      ON tmp_dd30_work(dnminorhyd);

   END IF;
   
   ----------------------------------------------------------------------------
   -- Step 20
   -- Create intermediate temp table
   ----------------------------------------------------------------------------
   IF nhdplus_navigation30.temp_table_exists('tmp_dd30_inter')
   THEN
      TRUNCATE TABLE tmp_dd30_inter;
      
   ELSE
      CREATE TEMPORARY TABLE tmp_dd30_inter(
          comid                       INTEGER
         ,hydroseq                    INTEGER
         ,levelpathid                 INTEGER
         ,dnhydroseq                  INTEGER
         ,dnminorhyd                  INTEGER
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
   INSERT INTO tmp_dd30_work(
       comid
      ,hydroseq
      ,levelpathid
      ,dnhydroseq
      ,dnminorhyd
      ,fmeasure
      ,tmeasure
      ,lengthkm
      ,flowtimeday
      ,network_distancekm
      ,network_flowtimeday
      ,nav_order
   )
   SELECT
    rc.comid
   ,rc.hydroseq
   ,rc.levelpathid
   ,rc.dnhydroseq
   ,rc.dnminorhyd
   ,rc.fmeasure
   ,rc.tmeasure
   ,rc.lengthkm
   ,rc.travtime
   ,rc.lengthkm + pStartDistanceKm
   ,rc.travtime + pStartFlowTimeDay
   ,pRecOrder + 1
   FROM
   nhdplus_navigation30.plusflowlinevaa_nav rc
   WHERE
   rc.hydroseq = pStartHydroSequence;
   
   GET DIAGNOSTICS int_updated = ROW_COUNT;
   
   IF int_updated = 0
   THEN
      RETURN 0;
      
   END IF;
   
   ary_stack := array_append(ary_stack,pStartHydroSequence);

   ----------------------------------------------------------------------------
   -- Step 50
   -- Start the loop
   ----------------------------------------------------------------------------
   int_analyze        := 1;
   int_depth          := pRecOrder + 2;
   int_final_counter  := 0;
   int_universe_count := 1;
   int_sanity         := 5000;
   
   WHILE int_universe_count > 0
   AND   int_sanity         > 0
   LOOP
   
      IF int_universe_count - int_analyze > 1000
      THEN
         ANALYZE tmp_dd30_work;
         
         int_analyze := int_universe_count;
         
      END IF;
      
   ----------------------------------------------------------------------------
   -- Step 60
   -- First process the main lines as we want main line priority
   ----------------------------------------------------------------------------
      FOR rec IN
         SELECT
          mq.comid
         ,mq.hydroseq
         ,mq.levelpathid
         ,mq.dnhydroseq
         ,mq.dnminorhyd
         ,mq.fmeasure
         ,mq.tmeasure
         ,mq.lengthkm
         ,mq.travtime AS flowtimeday
         ,mq.lengthkm + dd.network_distancekm  AS network_distancekm
         ,mq.travtime + dd.network_flowtimeday AS network_flowtimeday  
         FROM
         nhdplus_navigation30.plusflowlinevaa_nav mq
         CROSS JOIN
         tmp_dd30_work dd
         WHERE
             mq.hydroseq = dd.dnhydroseq
         AND (
               pMaxDistanceKm IS NULL
            OR dd.network_distancekm <= pMaxDistanceKm
         )
         AND (
               pMaxFlowTimeDay IS NULL
            OR dd.network_flowtimeday <= pMaxFlowTimeDay
         )
         AND NOT mq.hydroseq = ANY(ary_stack) 
      LOOP

         IF rec.hydroseq = ANY(ary_stack)
         THEN
            NULL;
            
         ELSE
            ary_stack := array_append(ary_stack,rec.hydroseq);
    
            INSERT INTO tmp_dd30_inter(
                comid
               ,hydroseq
               ,levelpathid
               ,dnhydroseq
               ,dnminorhyd
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
               ,rec.levelpathid
               ,rec.dnhydroseq
               ,rec.dnminorhyd
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
   -- Step 70
   -- Process the minor divergences
   ----------------------------------------------------------------------------
      FOR rec IN
         SELECT
          mq.comid
         ,mq.hydroseq
         ,mq.levelpathid
         ,mq.dnhydroseq
         ,mq.dnminorhyd
         ,mq.fmeasure
         ,mq.tmeasure
         ,mq.lengthkm
         ,mq.travtime AS flowtimeday
         ,mq.lengthkm + dd.network_distancekm  AS network_distancekm
         ,mq.travtime + dd.network_flowtimeday AS network_flowtimeday  
         FROM
         nhdplus_navigation30.plusflowlinevaa_nav mq
         CROSS JOIN
         tmp_dd30_work dd
         WHERE
             dd.dnminorhyd  = mq.hydroseq
         AND (
               pMaxDistanceKm IS NULL
            OR dd.network_distancekm <= pMaxDistanceKm
         )
         AND (
               pMaxFlowTimeDay IS NULL
            OR dd.network_flowtimeday <= pMaxFlowTimeDay
         )
         AND NOT mq.hydroseq = ANY(ary_stack)  
      LOOP

         IF rec.hydroseq = ANY(ary_stack)
         THEN
            NULL;
            
         ELSE
            ary_stack := array_append(ary_stack,rec.hydroseq);

            INSERT INTO tmp_dd30_inter(
                comid
               ,hydroseq
               ,levelpathid
               ,dnhydroseq
               ,dnminorhyd
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
               ,rec.levelpathid
               ,rec.dnhydroseq
               ,rec.dnminorhyd
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
   -- Step 80
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
      tmp_dd30_work a
      ON CONFLICT DO NOTHING;
      
      GET DIAGNOSTICS int_updated = ROW_COUNT;
      int_final_counter := int_final_counter + int_updated;
      
   ----------------------------------------------------------------------------
   -- Step 90
   -- Empty the work table
   ----------------------------------------------------------------------------
      TRUNCATE TABLE tmp_dd30_work;
      
   ----------------------------------------------------------------------------
   -- Step 100
   -- Move inter into work
   ----------------------------------------------------------------------------
      INSERT INTO tmp_dd30_work
      SELECT * FROM tmp_dd30_inter;
      
   ----------------------------------------------------------------------------
   -- Step 110
   -- Empty the inter table
   ----------------------------------------------------------------------------
      TRUNCATE TABLE tmp_dd30_inter;
      
   ----------------------------------------------------------------------------
   -- Step 120
   -- Get the count from the work table
   ----------------------------------------------------------------------------
      SELECT COUNT(*) 
      INTO int_universe_count
      FROM tmp_dd30_work; 

   ----------------------------------------------------------------------------
   -- Step 130
   -- Update loop conditions
   ----------------------------------------------------------------------------
      int_depth  := int_depth + 1;
      int_sanity := int_sanity - 1;
      
   END LOOP;
   
   ----------------------------------------------------------------------------
   -- Step 140
   -- Return total count of results
   ----------------------------------------------------------------------------
   RETURN int_final_counter;

END;
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION nhdplus_navigation30.nav_dd_calc(
    INTEGER
   ,INTEGER
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC   
) OWNER TO nhdplus_navigation30;

GRANT EXECUTE ON FUNCTION nhdplus_navigation30.nav_dd_calc(
    INTEGER
   ,INTEGER
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
)  TO PUBLIC;


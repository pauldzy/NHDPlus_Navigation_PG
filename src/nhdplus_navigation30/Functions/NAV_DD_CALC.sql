CREATE OR REPLACE FUNCTION nhdplus_navigation30.nav_dd_calc(
    IN  int_start_hydrosequence   INTEGER
   ,IN  int_rec_order             INTEGER
   ,IN  num_start_distance_km     NUMERIC
   ,IN  num_start_flowtime_day    NUMERIC
   ,IN  obj_start_flowline        nhdplus_navigation30.flowline         
   ,IN  num_maximum_distance_km   NUMERIC
   ,IN  num_maximum_flowtime_day  NUMERIC
   ,IN  int_min_hydrosequence     INTEGER
   ,IN  int_min_levelpathid       INTEGER
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
   IF int_start_hydrosequence IS NULL
   THEN
      INSERT INTO tmp_dd30_work(
          comid
         ,hydroseq
         ,levelpathid
         ,dnhydroseq
         ,fmeasure
         ,tmeasure
         ,lengthkm
         ,flowtimeday
         ,network_distancekm
         ,network_flowtimeday
         ,nav_order
      )
      SELECT
       obj_start_flowline.comid
      ,obj_start_flowline.hydrosequence
      ,obj_start_flowline.levelpathid
      ,obj_start_flowline.downhydrosequence
      ,obj_start_flowline.fmeasure
      ,obj_start_flowline.out_measure
      ,obj_start_flowline.out_lengthkm
      ,obj_start_flowline.out_flowtimeday
      ,obj_start_flowline.out_lengthkm
      ,obj_start_flowline.out_flowtimeday
      ,int_rec_order + 1;
      
      int_start_hydrosequence := obj_start_flowline.hydrosequence;

   ELSE
      INSERT INTO tmp_dd30_work(
          comid
         ,hydroseq
         ,levelpathid
         ,dnhydroseq
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
      ,rc.fmeasure
      ,rc.tmeasure
      ,rc.lengthkm
      ,rc.travtime
      ,rc.lengthkm + num_start_distance_km
      ,rc.travtime + num_start_flowtime_day
      ,int_rec_order + 1
      FROM
      nhdplus_navigation30.plusflowlinevaa_nav rc
      WHERE
      rc.hydroseq = int_start_hydrosequence;
      
   END IF;
   
   GET DIAGNOSTICS int_updated = ROW_COUNT;
   
   IF int_updated = 0
   THEN
      RETURN 0;
      
   END IF;
   
   ary_stack := array_append(ary_stack,int_start_hydrosequence);

   ----------------------------------------------------------------------------
   -- Step 50
   -- Start the loop
   ----------------------------------------------------------------------------
   int_analyze        := 1;
   int_depth          := int_rec_order + 2;
   int_final_counter  := 0;
   int_universe_count := 1;
   int_sanity         := 5000;
   
   WHILE int_universe_count > 0
   AND   int_sanity         > 0
   LOOP
   
      
      
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
               num_maximum_distance_km IS NULL
            OR dd.network_distancekm <= num_maximum_distance_km
         )
         AND (
               num_maximum_flowtime_day IS NULL
            OR dd.network_flowtimeday <= num_maximum_flowtime_day
         )
         AND (
               int_min_hydrosequence IS NULL
            OR dd.levelpathid <> int_min_levelpathid
            OR dd.hydroseq > int_min_hydrosequence
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
         WHERE (
                mq.hydroseq <> dd.dnhydroseq 
            AND mq.ary_upstream_hydroseq @> ARRAY[dd.hydroseq] 
         )
         AND (
               num_maximum_distance_km IS NULL
            OR dd.network_distancekm <= num_maximum_distance_km
         )
         AND (
               num_maximum_flowtime_day IS NULL
            OR dd.network_flowtimeday <= num_maximum_flowtime_day
         )
         AND (
               int_min_hydrosequence IS NULL
            OR dd.levelpathid <> int_min_levelpathid
            OR dd.hydroseq > int_min_hydrosequence
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
   ,nhdplus_navigation30.flowline
   ,NUMERIC
   ,NUMERIC
   ,INTEGER
   ,INTEGER
) OWNER TO nhdplus_navigation30;

GRANT EXECUTE ON FUNCTION nhdplus_navigation30.nav_dd_calc(
    INTEGER
   ,INTEGER
   ,NUMERIC
   ,NUMERIC
   ,nhdplus_navigation30.flowline
   ,NUMERIC
   ,NUMERIC
   ,INTEGER
   ,INTEGER
)  TO PUBLIC;


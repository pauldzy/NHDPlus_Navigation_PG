CREATE OR REPLACE FUNCTION nhdplus_navigation30.navigate(
    IN  pSearchType                  VARCHAR DEFAULT NULL
   ,IN  pStartComID                  INTEGER DEFAULT NULL
   ,IN  pStartPermanentIdentifier    VARCHAR DEFAULT NULL
   ,IN  pStartReachcode              VARCHAR DEFAULT NULL
   ,IN  pStartHydroSequence          INTEGER DEFAULT NULL
   ,IN  pStartMeasure                NUMERIC DEFAULT NULL
   ,IN  pStopComID                   INTEGER DEFAULT NULL
   ,IN  pStopPermanentIdentifier     VARCHAR DEFAULT NULL
   ,IN  pStopReachcode               VARCHAR DEFAULT NULL
   ,IN  pStopHydroSequence           INTEGER DEFAULT NULL
   ,IN  pStopMeasure                 NUMERIC DEFAULT NULL
   ,IN  pMaxDistanceKm               NUMERIC DEFAULT NULL
   ,IN  pMaxFlowTimeDay              NUMERIC DEFAULT NULL
   ,OUT pOutStartComID               INTEGER
   ,OUT pOutStartPermanentIdentifier VARCHAR
   ,OUT pOutStartMeasure             NUMERIC
   ,OUT pOutGridSRID                 INTEGER
   ,OUT pOutStopComID                INTEGER
   ,OUT pOutStopMeasure              NUMERIC
   ,OUT pFlowlineCount               INTEGER
   ,OUT pReturnCode                  NUMERIC
   ,OUT pStatusMessage               VARCHAR
   ,INOUT pSessionID                 VARCHAR DEFAULT NULL
)
VOLATILE
AS $BODY$
DECLARE
   r                              RECORD;
   rec                            RECORD;
   str_search_type                VARCHAR(16) := UPPER(pSearchType);

   int_start_comid                INTEGER     := pStartComID;
   str_start_permanent_identifier VARCHAR(40) := pStartPermanentIdentifier;
   str_start_reachcode            VARCHAR(14) := pStartReachcode;
   int_start_hydroseq             INTEGER     := pStartHydroSequence;
   num_start_measure              NUMERIC     := pStartMeasure;
   num_start_fmeasure             NUMERIC;
   num_start_tmeasure             NUMERIC;
   num_start_lengthkm             NUMERIC;
   num_start_flowtimeday          NUMERIC;
   num_start_length_ratio         NUMERIC;
   num_start_flowtime_ratio       NUMERIC;
   int_start_node                 INTEGER;
   num_start_pathlength           NUMERIC;
   num_start_pathtime             NUMERIC;
   num_start_original_pathlength  NUMERIC;
   num_start_original_pathtime    NUMERIC;
   int_start_dnminorhyd           INTEGER;
   int_start_levelpathid          INTEGER;
   int_start_uphydroseq           INTEGER;
   int_start_divergence           INTEGER;
   int_start_streamlevel          INTEGER;
   num_start_arbolatesum          NUMERIC;
   int_start_fcode                INTEGER;
   
   int_stop_comid                 INTEGER     := pStopComID;
   str_stop_permanent_identifier  VARCHAR(40) := pStopPermanentIdentifier;
   str_stop_reachcode             VARCHAR(14) := pStopReachcode;
   int_stop_hydroseq              INTEGER     := pStopHydroSequence;
   num_stop_measure               NUMERIC     := pStopMeasure;
   num_stop_fmeasure              NUMERIC;
   num_stop_tmeasure              NUMERIC;
   num_stop_lengthkm              NUMERIC;
   num_stop_flowtimeday           NUMERIC;
   num_stop_length_ratio          NUMERIC;
   num_stop_flowtime_ratio        NUMERIC;
   int_stop_node                  INTEGER;
   num_stop_pathlength            NUMERIC;
   num_stop_pathtime              NUMERIC;
   int_stop_fcode                 INTEGER;

   num_maximum_distance_km        NUMERIC     := pMaxDistanceKm;
   num_maximum_flowtime_day       NUMERIC     := pMaxFlowTimeDay;

   num_init_meas_total            NUMERIC;
   num_init_fmeasure              NUMERIC;
   num_init_tmeasure              NUMERIC;
   num_init_lengthkm              NUMERIC;
   num_init_flowtimeday           NUMERIC;
   num_init_baselengthkm          NUMERIC;
   num_init_baseflowtimeday       NUMERIC;

   boo_complete                   BOOLEAN;
   int_return_code                INTEGER;
   int_counter                    INTEGER;
   num_foo                        NUMERIC;
   int_check                      INTEGER;

BEGIN

   ----------------------------------------------------------------------------
   -- Step 10
   -- Check over incoming parameters
   ----------------------------------------------------------------------------
   pReturnCode := 0;

   str_search_type := nhdplus_navigation30.search_type(
      p_input := pSearchType
   );

   IF str_search_type NOT IN ('UM','UT','DM','DD','PP')
   THEN
      pReturnCode    := -1;
      pStatusMessage := 'Valid SearchType codes are UM, UT, DM, DD and PP.';
      RETURN;

   END IF;

   IF str_search_type = 'PP'
   THEN
      num_maximum_distance_km  := NULL;
      num_maximum_flowtime_day := NULL;

   END IF;

   IF  num_maximum_distance_km  IS NOT NULL
   AND num_maximum_flowtime_day IS NOT NULL
   THEN
      num_maximum_flowtime_day := NULL;

   END IF;
   
   IF num_maximum_distance_km = 0
   OR num_maximum_flowtime_day = 0
   THEN
      pReturnCode    := -3;
      pStatusMessage := 'Navigation for zero distance or flowtime is not valid.';
      RETURN;
   
   END IF;

   ----------------------------------------------------------------------------
   -- Step 20
   -- Verify or create the session id
   ----------------------------------------------------------------------------
   IF pSessionID IS NULL
   THEN
      pSessionID := '{' || uuid_generate_v1() || '}';

      INSERT INTO
      nhdplus_navigation30.tmp_navigation_status(
          objectid
         ,session_id
         ,session_datestamp
      ) VALUES (
          NEXTVAL('nhdplus_navigation30.tmp_navigation_status_seq')
         ,pSessionID
         ,(ABSTIME((CLOCK_TIMESTAMP()::TEXT)::TIMESTAMP(6) WITH TIME ZONE))
      );

   END IF;

   -----------------------------------------------------------------------------
   -- Step 30
   -- Flush or create the temp tables
   -----------------------------------------------------------------------------
   int_return_code := nhdplus_navigation30.create_temp_tables();

   ----------------------------------------------------------------------------
   -- Step 40
   -- Get the start and stop partial results
   ----------------------------------------------------------------------------
   r := nhdplus.get_flowline(
       p_direction            := str_search_type
      ,p_comid                := int_start_comid
      ,p_permanent_identifier := str_start_permanent_identifier
      ,p_reachcode            := str_start_reachcode
      ,p_hydrosequence        := int_start_hydroseq
      ,p_measure              := num_start_measure
   );
   int_start_comid                := r.p_comid;
   str_start_permanent_identifier := r.p_permanent_identifier;
   str_start_reachcode            := r.p_reachcode;
   int_start_hydroseq             := r.p_hydrosequence;
   num_start_measure              := r.p_measure;
   num_start_fmeasure             := r.p_fmeasure;
   num_start_tmeasure             := r.p_tmeasure;
   num_start_lengthkm             := r.p_lengthkm;
   num_start_flowtimeday          := r.p_flowtimeday;
   num_start_length_ratio         := r.p_length_ratio;
   num_start_flowtime_ratio       := r.p_flowtime_ratio;
   int_start_node                 := r.p_node;
   num_start_pathlength           := r.p_pathlength;
   num_start_pathtime             := r.p_pathtime;
   num_start_original_pathlength  := r.p_original_pathlength;
   num_start_original_pathtime    := r.p_original_pathtime;
   int_start_dnminorhyd           := r.p_dnminorhyd;
   int_start_levelpathid          := r.p_levelpathid;
   int_start_uphydroseq           := r.p_uphydroseq;
   int_start_divergence           := r.p_divergence;
   int_start_streamlevel          := r.p_streamlevel;
   num_start_arbolatesum          := r.p_arbolatesum;
   pOutGridSRID                   := r.p_grid_srid;
   int_start_fcode                := r.p_fcode;

   r := nhdplus.get_flowline(
       p_direction            := 'U'
      ,p_comid                := int_stop_comid
      ,p_permanent_identifier := str_stop_permanent_identifier
      ,p_reachcode            := str_stop_reachcode
      ,p_hydrosequence        := int_stop_hydroseq
      ,p_measure              := num_stop_measure
   );
   int_stop_comid                := r.p_comid;
   str_stop_permanent_identifier := r.p_permanent_identifier;
   str_stop_reachcode            := r.p_reachcode;
   int_stop_hydroseq             := r.p_hydrosequence;
   num_stop_measure              := r.p_measure;
   num_stop_fmeasure             := r.p_fmeasure;
   num_stop_tmeasure             := r.p_tmeasure;
   num_stop_lengthkm             := r.p_lengthkm;
   num_stop_flowtimeday          := r.p_flowtimeday;
   num_stop_length_ratio         := r.p_length_ratio;
   num_stop_flowtime_ratio       := r.p_flowtime_ratio;
   int_stop_node                 := r.p_node;
   num_stop_pathlength           := r.p_pathlength;
   num_stop_pathtime             := r.p_pathtime;
   int_stop_fcode                := r.p_fcode;

   IF int_start_fcode = 56600
   OR int_stop_fcode  = 56600
   THEN
      pReturnCode      := -56600;
      pStatusMessage   := 'Navigation from or to coastal flowlines is not valid.';
      
      pOutStartComID   := int_start_comid;
      pOutStartMeasure := num_start_measure;
      pOutStartPermanentIdentifier := str_start_permanent_identifier;
      pOutStopComID    := int_stop_comid;
      pOutStopMeasure  := num_stop_measure;
      
      UPDATE nhdplus_navigation30.tmp_navigation_status a
      SET
       return_code    = pReturnCode
      ,status_message = pStatusMessage
      WHERE
      a.session_id = pSessionID;
   
      RETURN;
   
   END IF;
   
   ----------------------------------------------------------------------------
   -- Step 50
   -- Turn PP around if stop above start
   ----------------------------------------------------------------------------
   IF int_stop_hydroseq > int_start_hydroseq
   THEN
      int_start_comid                := pStopComID;
      str_start_permanent_identifier := pStopPermanentIdentifier;
      str_start_reachcode            := pStopReachcode;
      int_start_hydroseq             := pStopHydroSequence;
      num_start_measure              := pStopMeasure;

      int_stop_comid                 := pStartComID;
      str_stop_permanent_identifier  := pStartPermanentIdentifier;
      str_stop_reachcode             := pStartReachcode;
      int_stop_hydroseq              := pStartHydroSequence;
      num_stop_measure               := pStartMeasure;

      r := nhdplus.get_flowline(
          p_direction            := str_search_type
         ,p_comid                := int_start_comid
         ,p_permanent_identifier := str_start_permanent_identifier
         ,p_reachcode            := str_start_reachcode
         ,p_hydrosequence        := int_start_hydroseq
         ,p_measure              := num_start_measure
      );
      int_start_comid                := r.p_comid;
      str_start_permanent_identifier := r.p_permanent_identifier;
      str_start_reachcode            := r.p_reachcode;
      int_start_hydroseq             := r.p_hydrosequence;
      num_start_measure              := r.p_measure;
      num_start_fmeasure             := r.p_fmeasure;
      num_start_tmeasure             := r.p_tmeasure;
      num_start_lengthkm             := r.p_lengthkm;
      num_start_flowtimeday          := r.p_flowtimeday;
      num_start_length_ratio         := r.p_length_ratio;
      num_start_flowtime_ratio       := r.p_flowtime_ratio;
      int_start_node                 := r.p_node;
      num_start_pathlength           := r.p_pathlength;
      num_start_pathtime             := r.p_pathtime;

      r := nhdplus.get_flowline(
          p_direction            := 'U'
         ,p_comid                := int_stop_comid
         ,p_permanent_identifier := str_stop_permanent_identifier
         ,p_reachcode            := str_stop_reachcode
         ,p_hydrosequence        := int_stop_hydroseq
         ,p_measure              := num_stop_measure
      );
      int_stop_comid                := r.p_comid;
      str_stop_permanent_identifier := r.p_permanent_identifier;
      str_stop_reachcode            := r.p_reachcode;
      int_stop_hydroseq             := r.p_hydrosequence;
      num_stop_measure              := r.p_measure;
      num_stop_fmeasure             := r.p_fmeasure;
      num_stop_tmeasure             := r.p_tmeasure;
      num_stop_lengthkm             := r.p_lengthkm;
      num_stop_flowtimeday          := r.p_flowtimeday;
      num_stop_length_ratio         := r.p_length_ratio;
      num_stop_flowtime_ratio       := r.p_flowtime_ratio;
      int_stop_node                 := r.p_node;
      num_stop_pathlength           := r.p_pathlength;
      num_stop_pathtime             := r.p_pathtime;

   END IF;
   
   pOutStartComID               := int_start_comid;
   pOutStartPermanentIdentifier := str_start_permanent_identifier;
   pOutStartMeasure             := num_start_measure;
   pOutStopComID                := int_stop_comid;
   pOutStopMeasure              := num_stop_measure;

   ----------------------------------------------------------------------------
   -- Step 60
   -- Create the initial flowline and deal with single flowline search
   ----------------------------------------------------------------------------
   IF int_start_comid = int_stop_comid
   THEN
      num_init_meas_total  := ABS(num_stop_measure - num_start_measure);
      num_init_lengthkm    := num_init_meas_total * num_start_length_ratio;
      num_init_flowtimeday := num_init_meas_total * num_start_flowtime_ratio;

      IF num_start_measure < num_stop_measure
      THEN
         num_init_fmeasure := num_start_measure;
         num_init_tmeasure := num_stop_measure;

      ELSE
         num_init_fmeasure := num_stop_measure;
         num_init_tmeasure := num_start_measure;

      END IF;

      boo_complete := TRUE;

   ELSIF num_maximum_distance_km < num_start_lengthkm
   THEN
      IF str_search_type IN ('UM','UT')
      THEN
         num_init_fmeasure := num_start_measure;
         num_init_tmeasure := num_start_measure + ROUND(num_maximum_distance_km / num_start_length_ratio,5);
         
      ELSE
         num_init_fmeasure := num_start_measure - ROUND(num_maximum_distance_km / num_start_length_ratio,5);
         num_init_tmeasure := num_start_measure;

      END IF;

      num_init_lengthkm    := num_maximum_distance_km;
      num_init_flowtimeday := (num_init_tmeasure - num_init_fmeasure) * num_start_flowtime_ratio;

      boo_complete := TRUE;

   ELSIF num_maximum_flowtime_day < num_start_flowtimeday
   THEN
      IF str_search_type IN ('UM','UT')
      THEN
         num_init_fmeasure := num_start_measure;
         num_init_tmeasure := num_start_measure + ROUND(num_maximum_flowtime_day / num_start_flowtime_ratio,5);
         
      ELSE
         num_init_fmeasure := num_start_measure - ROUND(num_maximum_flowtime_day / num_start_flowtime_ratio,5);
         num_init_tmeasure := num_start_measure;

      END IF;

      num_init_lengthkm    := (num_init_tmeasure - num_init_fmeasure) * num_start_length_ratio;
      num_init_flowtimeday := num_maximum_flowtime_day;

      boo_complete := TRUE;

   ELSE
      IF str_search_type IN ('UM','UT')
      THEN
         num_init_fmeasure := num_start_measure;
         num_init_tmeasure := num_start_tmeasure;

      ELSE
         num_init_fmeasure := num_start_fmeasure;
         num_init_tmeasure := num_start_measure;

      END IF;

      num_init_lengthkm    := num_start_lengthkm;
      num_init_flowtimeday := num_start_flowtimeday;

      boo_complete := FALSE;

   END IF;
   
   num_init_baselengthkm    := num_start_pathlength + (num_start_lengthkm    - num_init_lengthkm);
   num_init_baseflowtimeday := num_start_pathtime   + (num_start_flowtimeday - num_init_flowtimeday);

   ----------------------------------------------------------------------------
   -- Step 70
   -- Insert the initial flowline and tag the running counts
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
   ) VALUES (
       int_start_comid
      ,int_start_hydroseq
      ,num_init_fmeasure
      ,num_init_tmeasure
      ,num_init_lengthkm
      ,num_init_flowtimeday
      ,num_init_lengthkm
      ,num_init_flowtimeday
      ,0
   );

   ----------------------------------------------------------------------------
   -- Step 80
   -- Do upstream search with tributaries
   ----------------------------------------------------------------------------
   IF NOT boo_complete
   AND str_search_type = 'UT'
   THEN
    
      IF (
             num_maximum_distance_km  IS NULL
         AND num_maximum_flowtime_day IS NULL
         AND num_start_arbolatesum > 500
      ) OR (
             num_maximum_distance_km  IS NOT NULL
         AND num_maximum_distance_km > 200
         AND num_start_arbolatesum > 200
      ) OR (
             num_maximum_flowtime_day  IS NOT NULL
         AND num_maximum_flowtime_day > 3
         AND num_start_arbolatesum > 200
      )
      THEN
         num_init_baselengthkm    := num_start_original_pathlength + (num_start_lengthkm    - num_init_lengthkm);
         num_init_baseflowtimeday := num_start_original_pathtime   + (num_start_flowtimeday - num_init_flowtimeday);
      
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
             int_start_comid
            ,int_start_hydroseq
            ,int_start_levelpathid
            ,int_start_uphydroseq
            ,int_start_divergence
            ,num_init_fmeasure
            ,num_init_tmeasure
            ,num_init_lengthkm  -- segment lengthkm
            ,num_init_flowtimeday
            ,num_init_lengthkm  -- network distance
            ,num_init_flowtimeday
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
               OR (
                  --- Port Allen Bayou 4 way intersection --
                  mq.hydroseq = 350002946 AND um.hydroseq = 350002941
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
         um a
         WHERE
             a.comid    <> int_start_comid
         AND a.fmeasure <> a.tmeasure
         ON CONFLICT DO NOTHING;
         
         -------------------------------------------------------------------
         -- Extract the divs off the mainline
         -------------------------------------------------------------------
         int_counter = 1;

         FOR rec IN 
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
               ) VALUES (
                   rec.comid
                  ,rec.hydroseq
                  ,rec.fmeasure
                  ,rec.tmeasure
                  ,rec.lengthkm
                  ,rec.travtime
                  ,rec.network_distancekm
                  ,rec.network_flowtimeday
                  ,rec.nav_order
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
                   rec.comid
                  ,rec.hydroseq
                  ,rec.levelpathid
                  ,rec.fmeasure
                  ,rec.tmeasure
                  ,rec.lengthkm
                  ,rec.travtime
                  ,rec.lengthkm
                  ,rec.travtime
                  ,num_init_baselengthkm 
                  ,num_init_baseflowtimeday
                  ,rec.nav_order
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
               ut a
               WHERE
               a.comid <> rec.comid
               ON CONFLICT DO NOTHING;
               
               -- At some point this should be removed
               GET DIAGNOSTICS int_check = row_count;
               IF int_check > 10000
               THEN
                  RAISE WARNING '% %',rec.comid,int_check;
                  
               END IF;              
               
               int_counter := int_counter + 1;
               
            EXCEPTION
               WHEN UNIQUE_VIOLATION 
               THEN
                  NULL;

               WHEN OTHERS
               THEN               
                  RAISE;
                  
            END;

         END LOOP;

      ELSE   
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
             rc.comid
            ,rc.hydroseq
            ,rc.levelpathid
            ,num_init_fmeasure
            ,num_init_tmeasure
            ,num_init_lengthkm
            ,num_init_flowtimeday
            ,num_init_lengthkm
            ,num_init_flowtimeday
            ,rc.pathlength + (rc.lengthkm - num_init_lengthkm)
            ,rc.pathtime   + (rc.travtime - num_init_flowtimeday)
            ,0 AS nav_order
            FROM
            nhdplus_navigation30.plusflowlinevaa_nav rc
            WHERE
            rc.comid = int_start_comid
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
         ut a
         WHERE
             a.comid    <> int_start_comid
         AND a.fmeasure <> a.tmeasure
         ON CONFLICT DO NOTHING;         
      
      END IF;
           
   ----------------------------------------------------------------------------
   -- Step 90
   -- Do upstream search main line
   ----------------------------------------------------------------------------
   ELSIF NOT boo_complete
   AND str_search_type = 'UM'
   THEN
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
          rc.comid
         ,rc.hydroseq
         ,rc.levelpathid
         ,rc.uphydroseq
         ,rc.divergence
         ,num_init_fmeasure
         ,num_init_tmeasure
         ,num_init_lengthkm  -- segment lengthkm
         ,num_init_flowtimeday
         ,num_init_lengthkm  -- network distance
         ,num_init_flowtimeday
         ,rc.pathlength + (rc.lengthkm - num_init_lengthkm) -- base pathlength
         ,rc.pathtime   + (rc.travtime - num_init_flowtimeday)
         ,0 AS nav_order
         FROM
         nhdplus_navigation30.plusflowlinevaa_nav rc
         WHERE
         rc.comid = int_start_comid
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
         ,um.nav_order + 1 
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
         )
         AND(
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
      um a
      WHERE
          a.comid    <> int_start_comid
      AND a.fmeasure <> a.tmeasure;

   ----------------------------------------------------------------------------
   -- Step 100
   -- Do downstream search main line
   ----------------------------------------------------------------------------
   ELSIF NOT boo_complete
   AND str_search_type = 'DM'
   THEN
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
      )
      AS (
         SELECT
          rc.comid
         ,rc.hydroseq
         ,rc.dnhydroseq
         ,rc.terminalpathid
         ,num_init_fmeasure
         ,num_init_tmeasure
         ,num_init_lengthkm  -- segment lengthkm
         ,num_init_flowtimeday
         ,num_init_lengthkm  -- network distance
         ,num_init_flowtimeday
         ,rc.pathlength + num_init_lengthkm -- base pathlength
         ,rc.pathtime   + num_init_flowtimeday
         ,0 AS nav_order
         FROM
         nhdplus_navigation30.plusflowlinevaa_nav rc
         WHERE
         rc.comid = int_start_comid
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
         ,dm.nav_order + 1 
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
      dm a
      WHERE
          a.comid    <> int_start_comid
      AND a.fmeasure <> a.tmeasure;

   ----------------------------------------------------------------------------
   -- Step 100
   -- Do downstream with divergences when unbounded
   ----------------------------------------------------------------------------
   ELSIF NOT boo_complete
   AND str_search_type = 'DD'
   AND num_maximum_distance_km IS NULL
   AND num_maximum_flowtime_day IS NULL
   THEN
      int_counter = nhdplus_navigation30.distance_dd(
          pStartHydroSequence := int_start_hydroseq
         ,pRecOrder           := -1
         ,pStartDistanceKm    := num_init_lengthkm
         ,pStartFlowTimeDay   := num_init_flowtimeday
         ,pMaxDistanceKm      := NULL
         ,pMaxFlowTimeDay     := NULL
      );
      
   -------------------------------------------------------------------
   -- For limited DD
   -- Do downstream with divergences when bounded
   -------------------------------------------------------------------
   ELSIF NOT boo_complete
   AND str_search_type = 'DD'
   AND (
      num_maximum_distance_km IS NOT NULL
      OR num_maximum_flowtime_day IS NOT NULL
   )
   THEN
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
          rc.comid
         ,rc.hydroseq
         ,rc.dnhydroseq
         ,rc.dnminorhyd
         ,rc.terminalpathid
         ,num_init_fmeasure
         ,num_init_tmeasure
         ,num_init_lengthkm  -- segment lengthkm
         ,num_init_flowtimeday
         ,num_init_lengthkm  -- network distance
         ,num_init_flowtimeday
         ,rc.pathlength + num_init_lengthkm -- base pathlength
         ,rc.pathtime   + num_init_flowtimeday
         ,0 AS nav_order
         FROM
         nhdplus_navigation30.plusflowlinevaa_nav rc
         WHERE
         rc.comid = int_start_comid
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
      dm a
      WHERE
          a.comid    <> int_start_comid
      AND a.fmeasure <> a.tmeasure;
            
      -------------------------------------------------------------------
      -- Extract the divergences off the mainline
      -------------------------------------------------------------------
      FOR rec IN 
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
             int_start_comid
            ,int_start_dnminorhyd
            ,num_init_lengthkm
            ,num_init_flowtimeday
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
         int_counter = nhdplus_navigation30.distance_dd(
             pStartHydroSequence := rec.hydroseq
            ,pRecOrder           := rec.nav_order
            ,pStartDistanceKm    := rec.start_distancekm
            ,pStartFlowTimeDay   := rec.start_flowtimeday
            ,pMaxDistanceKm      := num_maximum_distance_km
            ,pMaxFlowTimeDay     := num_maximum_flowtime_day
         );

      END LOOP;

   ----------------------------------------------------------------------------
   -- Step 120
   -- Do Point to Point
   ----------------------------------------------------------------------------
   ELSIF NOT boo_complete
   AND str_search_type = 'PP'
   THEN
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
          rc.comid
         ,rc.hydroseq
         ,rc.dnhydroseq
         ,rc.terminalpathid
         ,num_init_fmeasure
         ,num_init_tmeasure
         ,num_init_lengthkm
         ,num_init_flowtimeday
         ,num_init_lengthkm
         ,num_init_flowtimeday
         ,rc.pathlength + num_init_lengthkm -- base pathlength
         ,rc.pathtime   + num_init_flowtimeday
         ,0 AS nav_order
         FROM
         nhdplus_navigation30.plusflowlinevaa_nav rc
         WHERE
         rc.comid = int_start_comid
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
         AND mq.hydroseq       >= int_stop_hydroseq
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
      pp a
      WHERE
          a.comid    <> int_start_comid
      AND a.fmeasure <> a.tmeasure;
      
      SELECT
      COUNT(*)
      INTO int_counter
      FROM 
      tmp_navigation_working30 a
      WHERE
      a.comid = int_stop_comid;
      
      -------------------------------------------------------------------------
      -- Next try divergences search as less likely
      -------------------------------------------------------------------------
      IF int_counter = 0
      THEN
         int_return_code := nhdplus_navigation30.create_tmp_network();
         
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
             rc.comid
            ,rc.hydroseq
            ,rc.dnhydroseq
            ,rc.dnminorhyd
            ,num_init_fmeasure
            ,num_init_tmeasure
            ,num_init_lengthkm
            ,num_init_flowtimeday
            ,num_init_lengthkm
            ,num_init_flowtimeday
            ,rc.pathlength + num_init_lengthkm -- base pathlength
            ,rc.pathtime   + num_init_flowtimeday
            ,rc.fromnode
            ,rc.tonode
            ,1::FLOAT8
            FROM
            nhdplus_navigation30.plusflowlinevaa_nav rc
            WHERE
            rc.comid = int_start_comid
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
            WHERE (
               mq.hydroseq = ppdd.dnhydroseq
               OR
               (
                      ppdd.dnminorhyd != 0
                  AND ppdd.dnminorhyd  = mq.hydroseq
               )
            )
            AND mq.hydroseq >= int_stop_hydroseq
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
         INTO int_counter
         FROM 
         tmp_network_working30 a
         WHERE
         a.comid = int_stop_comid;
         
         TRUNCATE TABLE tmp_navigation_working30;
 
         IF int_counter > 0
         THEN
            -- Remove duplicate flowlines keeping the cheapest cost
            DELETE FROM tmp_network_working30 a
            WHERE a.ctid IN (
               SELECT b.ctid FROM (
                  SELECT
                   bb.ctid
                  ,ROW_NUMBER() OVER (PARTITION BY bb.comid ORDER BY bb.COST ASC) AS rnum
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
                  ,int_start_node
                  ,int_stop_node
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
            ) VALUES (
                int_start_comid
               ,int_start_hydroseq
               ,num_init_fmeasure
               ,num_init_tmeasure
               ,num_init_lengthkm
               ,num_init_flowtimeday
               ,num_init_lengthkm
               ,num_init_flowtimeday
               ,0
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
            ) VALUES (
                int_stop_comid
               ,int_stop_hydroseq
               ,num_stop_measure
               ,num_stop_tmeasure
               ,num_stop_lengthkm
               ,num_stop_flowtimeday
               ,num_start_pathlength - num_stop_pathlength 
               ,num_start_pathtime   - num_stop_pathtime
               ,99999999                  
            );
            
         END IF;
      
      ELSE
         UPDATE tmp_navigation_working30 a
         SET
          fmeasure            = num_stop_measure
         ,tmeasure            = num_stop_tmeasure
         ,lengthkm            = num_stop_lengthkm
         ,flowtimeday         = num_stop_flowtimeday
         ,network_distancekm  = a.network_distancekm  + num_stop_lengthkm
         ,network_flowtimeday = a.network_flowtimeday + num_stop_flowtimeday
         WHERE
         a.comid = int_stop_comid;
      
      END IF;

      boo_complete := TRUE;

   END IF;

   ----------------------------------------------------------------------------
   -- Step 130
   -- Trim endings
   ----------------------------------------------------------------------------
   IF NOT boo_complete
   THEN
      IF num_maximum_distance_km IS NOT NULL
      THEN
         UPDATE tmp_navigation_working30 a
         SET (
             fmeasure
            ,tmeasure
            ,lengthkm
            ,flowtimeday
            ,network_distancekm
            ,network_flowtimeday
         ) = (
            SELECT
             aa.fmeasure
            ,aa.tmeasure
            ,aa.lengthkm
            ,aa.flowtimeday
            ,aa.network_distancekm
            ,aa.network_flowtimeday
            FROM
            nhdplus_navigation30.trim_temp(
                p_search_type          := str_search_type
               ,p_fmeasure             := a.fmeasure
               ,p_tmeasure             := a.tmeasure
               ,p_lengthkm             := a.lengthkm
               ,p_flowtimeday          := a.flowtimeday
               ,p_network_distancekm   := a.network_distancekm
               ,p_network_flowtimeday  := a.network_flowtimeday
               ,p_maximum_distance_km  := num_maximum_distance_km
               ,p_maximum_flowtime_day := num_maximum_flowtime_day
            ) aa
         )
         WHERE
         a.network_distancekm > num_maximum_distance_km;

      ELSIF num_maximum_flowtime_day IS NOT NULL
      THEN
         UPDATE tmp_navigation_working30 a
         SET (
             fmeasure
            ,tmeasure
            ,lengthkm
            ,flowtimeday
            ,network_distancekm
            ,network_flowtimeday
         ) = (
            SELECT
             aa.fmeasure
            ,aa.tmeasure
            ,aa.lengthkm
            ,aa.flowtimeday
            ,aa.network_distancekm
            ,aa.network_flowtimeday
            FROM
            nhdplus_navigation30.trim_temp(
                p_search_type          := str_search_type
               ,p_fmeasure             := a.fmeasure
               ,p_tmeasure             := a.tmeasure
               ,p_lengthkm             := a.lengthkm
               ,p_flowtimeday          := a.flowtimeday
               ,p_network_distancekm   := a.network_distancekm
               ,p_network_flowtimeday  := a.network_flowtimeday
               ,p_maximum_distance_km  := num_maximum_distance_km
               ,p_maximum_flowtime_day := num_maximum_flowtime_day
            ) aa
         )
         WHERE
         a.network_flowtimeday > num_maximum_flowtime_day;

      END IF;

   END IF;

   ----------------------------------------------------------------------------
   -- Step 140
   -- Load the final table
   ----------------------------------------------------------------------------
   INSERT INTO nhdplus_navigation30.tmp_navigation_results(
       objectid
      ,session_id
      ,comid
      ,permanent_identifier
      ,reachcode
      ,fmeasure
      ,tmeasure
      ,network_distancekm
      ,network_flowtimeday
      ,hydrosequence
      ,levelpathid
      ,terminalpathid
      ,uphydroseq
      ,dnhydroseq
      ,lengthkm
      ,length_measure_ratio
      ,flowtimeday
      ,flowtime_measure_ratio
      ,reachsmdate
      ,ftype
      ,fcode
      ,fcode_str
      ,gnis_id
      ,gnis_name
      ,wbarea_permanent_identifier
      ,wbarea_comid
      ,wbd_huc12
      ,catchment_featureid
      ,navigable
      ,coastal
      ,innetwork
      ,shape
      ,nav_order
   )
   SELECT
    nextval('nhdplus_navigation30.tmp_navigation_results_seq')
   ,pSessionID
   ,a.comid
   ,a.permanent_identifier
   ,a.reachcode
   ,a.fmeasure
   ,a.tmeasure
   ,a.network_distancekm
   ,a.network_flowtimeday
   ,a.hydrosequence
   ,a.levelpathid
   ,a.terminalpathid
   ,a.uphydroseq
   ,a.dnhydroseq
   ,a.lengthkm
   ,a.length_measure_ratio
   ,a.flowtimeday
   ,a.flowtime_measure_ratio
   ,a.reachsmdate
   ,a.ftype
   ,a.fcode
   ,a.fcode_str
   ,a.gnis_id
   ,a.gnis_name
   ,a.wbarea_permanent_identifier
   ,a.wbarea_comid
   ,a.wbd_huc12
   ,a.catchment_featureid
   ,a.navigable
   ,a.coastal
   ,a.innetwork
   ,a.shape
   ,a.nav_order
   FROM (
      SELECT
       aa.comid
      ,aa.permanent_identifier
      ,aa.reachcode
      ,aa.fmeasure
      ,aa.tmeasure
      ,aa.network_distancekm
      ,aa.network_flowtimeday
      ,aa.hydrosequence
      ,aa.levelpathid
      ,aa.terminalpathid
      ,aa.uphydroseq
      ,aa.dnhydroseq
      ,aa.lengthkm
      ,aa.length_measure_ratio
      ,aa.flowtimeday
      ,aa.flowtime_measure_ratio
      ,aa.reachsmdate
      ,aa.ftype
      ,aa.fcode
      ,bb.description AS fcode_str
      ,aa.gnis_id
      ,aa.gnis_name
      ,aa.wbarea_permanent_identifier
      ,aa.wbarea_comid
      ,aa.wbd_huc12
      ,aa.catchment_featureid
      ,aa.navigable
      ,aa.coastal
      ,aa.innetwork
      ,aa.shape
      ,aa.nav_order
      FROM (
         SELECT
          aaa.comid
         ,bbb.permanent_identifier
         ,bbb.reachcode
         ,aaa.fmeasure
         ,aaa.tmeasure
         ,aaa.network_distancekm
         ,aaa.network_flowtimeday
         ,bbb.hydroseq AS hydrosequence
         ,bbb.levelpathid
         ,bbb.terminalpathid
         ,bbb.uphydroseq
         ,bbb.dnhydroseq
         ,aaa.lengthkm
         ,bbb.lengthkm / (bbb.tmeasure - bbb.fmeasure) AS length_measure_ratio
         ,aaa.flowtimeday
         ,CASE 
          WHEN bbb.flowtimeday IS NULL
          THEN
            NULL
          ELSE
            bbb.flowtimeday / (bbb.tmeasure - bbb.fmeasure) 
          END AS flowtime_measure_ratio
         ,bbb.reachsmdate
         ,bbb.ftype
         ,bbb.fcode
         ,bbb.gnis_id
         ,bbb.gnis_name
         ,bbb.wbarea_permanent_identifier
         ,bbb.wbarea_nhdplus_comid AS wbarea_comid
         ,bbb.wbd_huc12
         ,bbb.catchment_featureid
         ,bbb.navigable
         ,bbb.coastal
         ,bbb.innetwork
         ,CASE
          WHEN aaa.fmeasure <> bbb.fmeasure
          OR   aaa.tmeasure <> bbb.fmeasure
          THEN
            ST_GeometryN(
                ST_LocateBetween(bbb.shape,aaa.fmeasure,aaa.tmeasure)
               ,1
            )
          ELSE
            bbb.shape
          END AS shape
         ,aaa.nav_order
         FROM
         tmp_navigation_working30 aaa
         JOIN
         nhdplus.nhdflowline_np21 bbb
         ON
         aaa.comid = bbb.nhdplus_comid
         WHERE
             aaa.fmeasure <> aaa.tmeasure
         AND aaa.fmeasure >= 0 AND aaa.fmeasure <= 100
         AND aaa.tmeasure >= 0 AND aaa.tmeasure <= 100
         AND aaa.lengthkm > 0
      ) aa
      JOIN
      nhdplus.nhdfcode_np21 bb
      ON
      aa.fcode = bb.fcode
      ORDER BY
       aa.nav_order
      ,aa.network_distancekm
   ) a;
   
   GET DIAGNOSTICS pFlowlineCount = ROW_COUNT;
   
   IF pFlowlineCount = 0
   THEN
      pReturnCode    := -1;
      pStatusMessage := 'No results found.';
   
   END IF;

   ----------------------------------------------------------------------------
   -- Step 150
   -- Exit with zero
   ----------------------------------------------------------------------------
   UPDATE nhdplus_navigation30.tmp_navigation_status a
   SET
    return_code    = pReturnCode
   ,status_message = pStatusMessage
   WHERE
   a.session_id = pSessionID;

END;
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION nhdplus_navigation30.navigate(
    VARCHAR
   ,INTEGER
   ,VARCHAR
   ,VARCHAR
   ,INTEGER
   ,NUMERIC
   ,INTEGER
   ,VARCHAR
   ,VARCHAR
   ,INTEGER
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
   ,VARCHAR
) OWNER TO nhdplus_navigation30;

GRANT EXECUTE ON FUNCTION nhdplus_navigation30.navigate(
    VARCHAR
   ,INTEGER
   ,VARCHAR
   ,VARCHAR
   ,INTEGER
   ,NUMERIC
   ,INTEGER
   ,VARCHAR
   ,VARCHAR
   ,INTEGER
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
   ,VARCHAR
)  TO PUBLIC;


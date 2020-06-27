CREATE OR REPLACE FUNCTION nhdplus_navigation30.navigate(
    IN  pSearchType                  VARCHAR DEFAULT NULL
   ,IN  pStartComID                  INTEGER DEFAULT NULL
   ,IN  pStartPermanentIdentifier    VARCHAR DEFAULT NULL
   ,IN  pStartReachCode              VARCHAR DEFAULT NULL
   ,IN  pStartHydroSequence          INTEGER DEFAULT NULL
   ,IN  pStartMeasure                NUMERIC DEFAULT NULL
   ,IN  pStopComID                   INTEGER DEFAULT NULL
   ,IN  pStopPermanentIdentifier     VARCHAR DEFAULT NULL
   ,IN  pStopReachCode               VARCHAR DEFAULT NULL
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
   str_search_type                VARCHAR(16) := UPPER(pSearchType); 
   obj_start_flowline             nhdplus_navigation30.flowline;
   obj_stop_flowline              nhdplus_navigation30.flowline;
   num_maximum_distance_km        NUMERIC     := pMaxDistanceKm;
   num_maximum_flowtime_day       NUMERIC     := pMaxFlowTimeDay;
   int_counter                    INTEGER;
   int_check                      INTEGER;

BEGIN

   ----------------------------------------------------------------------------
   -- Step 10
   -- Check over incoming parameters
   ----------------------------------------------------------------------------
   pReturnCode        := 0;
   obj_start_flowline := nhdplus_navigation30.flowline_constructor();
   obj_stop_flowline  := nhdplus_navigation30.flowline_constructor();

   str_search_type := nhdplus_navigation30.search_type(
      p_input := pSearchType
   );

   IF str_search_type NOT IN ('UM','UT','DM','DD','PP')
   THEN
      pReturnCode    := -1;
      pStatusMessage := 'Valid SearchType codes are UM, UT, DM, DD and PP.';

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
   
   IF pReturnCode <> 0
   THEN
      UPDATE nhdplus_navigation30.tmp_navigation_status a
      SET
       return_code    = pReturnCode
      ,status_message = pStatusMessage
      WHERE
      a.session_id = pSessionID;
      
      RETURN;
      
   END IF;

   ----------------------------------------------------------------------------
   -- Step 30
   -- Flush or create the temp tables
   ----------------------------------------------------------------------------
   int_check := nhdplus_navigation30.create_temp_tables();

   ----------------------------------------------------------------------------
   -- Step 40
   -- Get the start flowline
   ----------------------------------------------------------------------------
   r := nhdplus_navigation30.get_flowline(
       p_direction            := str_search_type
      ,p_comid                := pStartComID
      ,p_permanent_identifier := pStartPermanentIdentifier
      ,p_reachcode            := pStartReachCode
      ,p_hydrosequence        := pStartHydroSequence
      ,p_measure              := pStartMeasure
   );
   pReturnCode        := r.p_return_code;
   pStatusMessage     := r.p_status_message;
   
   IF pReturnCode <> 0
   THEN
      IF pReturnCode = -10
      THEN
         pStatusMessage := 'Flowline ' || COALESCE(
             pStartComID::VARCHAR
            ,pStartPermanentIdentifier
            ,pStartReachCode
            ,pStartHydroSequence::VARCHAR
            ,'err'
         );
         
         IF pStartMeasure IS NOT NULL
         THEN
            pStatusMessage := pStatusMessage || ' at measure ' || pStartMeasure::VARCHAR;
            
         END IF;
         
         pStatusMessage := pStatusMessage || ' not found in NHDPlus stream network.';
         
      END IF;
      
      UPDATE nhdplus_navigation30.tmp_navigation_status a
      SET
       return_code    = pReturnCode
      ,status_message = pStatusMessage
      WHERE
      a.session_id = pSessionID;
      
      RETURN;
      
   END IF;

   IF r.p_flowline IS NULL
   THEN
      RAISE EXCEPTION 'start get flowline returned no results';
   
   END IF;
   
   obj_start_flowline := r.p_flowline;
   pOutGridSRID := obj_start_flowline.out_grid_srid;
   
   IF obj_start_flowline.innetwork = 'N'
   THEN
      pReturnCode    := -22;
      pStatusMessage := 'Start flowline is not part of the NHDPlus network.';
      
      UPDATE nhdplus_navigation30.tmp_navigation_status a
      SET
       return_code    = pReturnCode
      ,status_message = pStatusMessage
      WHERE
      a.session_id = pSessionID;
      
      RETURN;
   
   ELSIF num_maximum_flowtime_day IS NOT NULL
   AND   obj_start_flowline.flowtimeday IS NULL
   THEN
      pReturnCode    := -23;
      pStatusMessage := 'Start flowline is tidal without flow time information.';
      
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
   -- Get the stop flowline
   ----------------------------------------------------------------------------
   IF str_search_type = 'PP'
   THEN
      r := nhdplus_navigation30.get_flowline(
          p_direction            := 'U'
         ,p_comid                := pStopComID
         ,p_permanent_identifier := pStopPermanentIdentifier
         ,p_reachcode            := pStopReachCode
         ,p_hydrosequence        := pStopHydroSequence
         ,p_measure              := pStopMeasure
      );
      pReturnCode       := r.p_return_code;
      pStatusMessage    := r.p_status_message;

      IF pReturnCode <> 0
      THEN
         UPDATE nhdplus_navigation30.tmp_navigation_status a
         SET
          return_code    = pReturnCode
         ,status_message = pStatusMessage
         WHERE
         a.session_id = pSessionID;
         
         RETURN;
         
      END IF;
   
      IF r.p_flowline IS NULL
      THEN
         RAISE EXCEPTION 'stop get flowline returned no results';
      
      END IF;
      
      obj_stop_flowline := r.p_flowline;

      IF obj_stop_flowline.innetwork = 'N'
      THEN
         pReturnCode    := -22;
         pStatusMessage := 'Stop flowline is not part of the NHDPlus network.';
      
         UPDATE nhdplus_navigation30.tmp_navigation_status a
         SET
          return_code    = pReturnCode
         ,status_message = pStatusMessage 
         WHERE
         a.session_id = pSessionID;
         
         RETURN;
      
      ELSIF num_maximum_flowtime_day IS NOT NULL
      AND   obj_stop_flowline.flowtimeday IS NULL
      THEN
         pReturnCode    := -23;
         pStatusMessage := 'Stop flowline is tidal without flow time information.';
         
         UPDATE nhdplus_navigation30.tmp_navigation_status a
         SET
          return_code    = pReturnCode
         ,status_message = pStatusMessage
         WHERE
         a.session_id = pSessionID;
         
         RETURN;
         
      END IF;
      
   END IF;

   ----------------------------------------------------------------------------
   -- Step 60
   -- Turn PP around if stop above start
   ----------------------------------------------------------------------------
   IF obj_stop_flowline.hydrosequence > obj_start_flowline.hydrosequence
   THEN
      r := nhdplus_navigation30.get_flowline(
          p_direction            := str_search_type
         ,p_comid                := pStopComID
         ,p_permanent_identifier := pStopPermanentIdentifier
         ,p_reachcode            := pStopReachCode
         ,p_hydrosequence        := pStopHydroSequence
         ,p_measure              := pStopMeasure
      );
      pReturnCode        := r.p_return_code;
      pStatusMessage     := r.p_status_message;
      obj_start_flowline := r.p_flowline;
      
      r := nhdplus_navigation30.get_flowline(
          p_direction            := 'U'
         ,p_comid                := pStartComID
         ,p_permanent_identifier := pStartPermanentIdentifier
         ,p_reachcode            := pStartReachCode
         ,p_hydrosequence        := pStartHydroSequence
         ,p_measure              := pStartMeasure
      );
      pReturnCode       := r.p_return_code;
      pStatusMessage    := r.p_status_message;
      obj_stop_flowline := r.p_flowline;

   END IF;
   
   pOutStartComID               := obj_start_flowline.comid;
   pOutStartPermanentIdentifier := obj_start_flowline.permanent_identifier;
   pOutStartMeasure             := obj_start_flowline.out_measure;
   pOutStopComID                := obj_stop_flowline.comid;
   pOutStopMeasure              := obj_stop_flowline.out_measure;

   ----------------------------------------------------------------------------
   -- Step 70
   -- Abend if start or stop is coastal
   ----------------------------------------------------------------------------
   IF obj_start_flowline.fcode = 56600
   OR obj_stop_flowline.fcode  = 56600
   THEN
      pReturnCode      := -56600;
      pStatusMessage   := 'Navigation from or to coastal flowlines is not valid.';
      
      UPDATE nhdplus_navigation30.tmp_navigation_status a
      SET
       return_code    = pReturnCode
      ,status_message = pStatusMessage
      WHERE
      a.session_id = pSessionID;
   
      RETURN;
   
   END IF;

   ----------------------------------------------------------------------------
   -- Step 80
   -- Create the initial flowline and deal with single flowline search
   ----------------------------------------------------------------------------
   IF obj_start_flowline.comid = obj_stop_flowline.comid
   OR num_maximum_distance_km < obj_start_flowline.out_lengthkm
   OR num_maximum_flowtime_day < obj_start_flowline.out_flowtimeday
   THEN
      int_counter := nhdplus_navigation30.nav_single(
          str_search_type          := str_search_type
         ,obj_start_flowline       := obj_start_flowline
         ,obj_stop_flowline        := obj_stop_flowline
         ,num_maximum_distance_km  := num_maximum_distance_km
         ,num_maximum_flowtime_day := num_maximum_flowtime_day
      );

   ELSE
   
   ----------------------------------------------------------------------------
   -- Step 90
   -- Do Point to Point
   ----------------------------------------------------------------------------
      IF str_search_type = 'PP'
      THEN
         int_counter := nhdplus_navigation30.nav_pp(
             obj_start_flowline       := obj_start_flowline
            ,obj_stop_flowline        := obj_stop_flowline
         );
         
      ELSE
   ----------------------------------------------------------------------------
   -- Step 100
   -- Do upstream search with tributaries
   ----------------------------------------------------------------------------
         IF str_search_type = 'UT'
         THEN 
            IF (
                   num_maximum_distance_km  IS NULL
               AND num_maximum_flowtime_day IS NULL
               AND obj_start_flowline.arbolatesum > 500
            ) OR (
                   num_maximum_distance_km  IS NOT NULL
               AND num_maximum_distance_km > 200
               AND obj_start_flowline.arbolatesum > 200
            ) OR (
                   num_maximum_flowtime_day  IS NOT NULL
               AND num_maximum_flowtime_day > 3
               AND obj_start_flowline.arbolatesum > 200
            )
            THEN
               int_counter := nhdplus_navigation30.nav_ut_extended(
                   obj_start_flowline       := obj_start_flowline
                  ,num_maximum_distance_km  := num_maximum_distance_km
                  ,num_maximum_flowtime_day := num_maximum_flowtime_day
               );

            ELSE   
               int_counter := nhdplus_navigation30.nav_ut_concise(
                   obj_start_flowline       := obj_start_flowline
                  ,num_maximum_distance_km  := num_maximum_distance_km
                  ,num_maximum_flowtime_day := num_maximum_flowtime_day
               );

            END IF;
                 
   ----------------------------------------------------------------------------
   -- Step 110
   -- Do upstream search main line
   ----------------------------------------------------------------------------
         ELSIF str_search_type = 'UM'
         THEN
            int_counter := nhdplus_navigation30.nav_um(
                obj_start_flowline       := obj_start_flowline
               ,num_maximum_distance_km  := num_maximum_distance_km
               ,num_maximum_flowtime_day := num_maximum_flowtime_day
            );

   ----------------------------------------------------------------------------
   -- Step 120
   -- Do downstream search main line
   ----------------------------------------------------------------------------
         ELSIF str_search_type = 'DM'
         THEN
            int_counter := nhdplus_navigation30.nav_dm(
                obj_start_flowline       := obj_start_flowline
               ,num_maximum_distance_km  := num_maximum_distance_km
               ,num_maximum_flowtime_day := num_maximum_flowtime_day
            );

   ----------------------------------------------------------------------------
   -- Step 130
   -- Do downstream with divergences 
   -------------------------------------------------------------------
         ELSIF str_search_type = 'DD'
         THEN
            int_counter := nhdplus_navigation30.nav_dd(
                obj_start_flowline       := obj_start_flowline
               ,num_maximum_distance_km  := num_maximum_distance_km
               ,num_maximum_flowtime_day := num_maximum_flowtime_day
            );

         ELSE
            RAISE EXCEPTION 'err';
            
         END IF;

   ----------------------------------------------------------------------------
   -- Step 140
   -- Trim endings and mark partial flowline termination flags
   ----------------------------------------------------------------------------
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
               ,navtermination_flag
            ) = (
               SELECT
                aa.fmeasure
               ,aa.tmeasure
               ,aa.lengthkm
               ,aa.flowtimeday
               ,aa.network_distancekm
               ,aa.network_flowtimeday
               ,2
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
                a.selected IS TRUE
            AND a.network_distancekm > num_maximum_distance_km;

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
               ,navtermination_flag
            ) = (
               SELECT
                aa.fmeasure
               ,aa.tmeasure
               ,aa.lengthkm
               ,aa.flowtimeday
               ,aa.network_distancekm
               ,aa.network_flowtimeday
               ,2
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
                a.selected IS TRUE
            AND a.network_flowtimeday > num_maximum_flowtime_day;

         END IF;
         
      END IF;
      
   END IF;
   
   ----------------------------------------------------------------------------
   -- Step 160
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
      ,navtermination_flag
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
   ,a.navtermination_flag
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
      ,aa.navtermination_flag
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
         ,bbb.wbarea_comid
         ,bbb.wbd_huc12
         ,bbb.catchment_featureid
         ,bbb.navigable
         ,bbb.coastal
         ,bbb.innetwork
         ,aaa.navtermination_flag
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
         aaa.comid = bbb.comid
         WHERE
             aaa.selected IS TRUE
         AND aaa.fmeasure <> aaa.tmeasure
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
   -- Step 170
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


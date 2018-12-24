CREATE OR REPLACE FUNCTION nhdplus_navigation30.seed_results(
    IN  pSessionID                VARCHAR
   ,IN  pComID                    INTEGER
   ,IN  pFMeasure                 NUMERIC DEFAULT NULL
   ,IN  pTMeasure                 NUMERIC DEFAULT NULL
   ,IN  pNavOrder                 INTEGER DEFAULT 1
) RETURNS BOOLEAN
VOLATILE
AS $BODY$
DECLARE
   
BEGIN

   ----------------------------------------------------------------------------
   -- Step 10
   -- Insert seed record
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
   ,a.nhdplus_comid
   ,a.permanent_identifier
   ,a.reachcode
   ,a.fmeasure
   ,a.tmeasure
   ,a.lengthkm AS network_distancekm
   ,a.flowtimeday AS network_flowtimeday
   ,a.hydroseq AS hydrosequence
   ,a.levelpathid
   ,a.terminalpathid
   ,a.uphydroseq
   ,a.dnhydroseq
   ,a.lengthkm
   ,a.lengthkm / (a.tmeasure - a.fmeasure) AS length_measure_ratio
   ,a.flowtimeday
   ,CASE 
    WHEN a.flowtimeday IS NULL
    THEN
      NULL
    ELSE
      a.flowtimeday / (a.tmeasure - a.fmeasure) 
    END AS flowtime_measure_ratio
   ,a.reachsmdate
   ,a.ftype
   ,a.fcode
   ,b.description AS fcode_str
   ,a.gnis_id
   ,a.gnis_name
   ,a.wbarea_permanent_identifier
   ,a.wbarea_nhdplus_comid
   ,a.wbd_huc12
   ,a.catchment_featureid
   ,a.navigable
   ,a.coastal
   ,a.innetwork
   ,a.shape
   ,pNavOrder
   FROM
   nhdplus.nhdflowline_np21 a
   JOIN
   nhdplus.nhdfcode_np21 b
   ON
   a.fcode = b.fcode
   WHERE
   a.nhdplus_comid = pComID;
   
   RETURN TRUE;

END;
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION nhdplus_navigation30.seed_results(
    VARCHAR
   ,INTEGER
   ,NUMERIC
   ,NUMERIC
   ,INTEGER
) OWNER TO nhdplus_navigation30;

GRANT EXECUTE ON FUNCTION nhdplus_navigation30.seed_results(
    VARCHAR
   ,INTEGER
   ,NUMERIC
   ,NUMERIC
   ,INTEGER
)  TO PUBLIC;


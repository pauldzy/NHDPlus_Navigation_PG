CREATE OR REPLACE FUNCTION nhdplus_navigation30.trim_temp(
    IN  p_search_type          VARCHAR
   ,IN  p_fmeasure             NUMERIC
   ,IN  p_tmeasure             NUMERIC
   ,IN  p_lengthkm             NUMERIC
   ,IN  p_flowtimeday          NUMERIC
   ,IN  p_network_distancekm   NUMERIC
   ,IN  p_network_flowtimeday  NUMERIC
   ,IN  p_maximum_distance_km  NUMERIC
   ,IN  p_maximum_flowtime_day NUMERIC
) RETURNS TABLE(
    fmeasure            NUMERIC
   ,tmeasure            NUMERIC
   ,lengthkm            NUMERIC
   ,flowtimeday         NUMERIC
   ,network_distancekm  NUMERIC
   ,network_flowtimeday NUMERIC
)
IMMUTABLE
AS $BODY$ 
DECLARE
   num_fmeasure            NUMERIC := p_fmeasure;
   num_tmeasure            NUMERIC := p_tmeasure;
   num_lengthkm            NUMERIC := p_lengthkm;
   num_flowtimeday         NUMERIC := p_flowtimeday;
   num_network_distancekm  NUMERIC := p_network_distancekm;
   num_network_flowtimeday NUMERIC := p_network_flowtimeday;
   
   num_ratio               NUMERIC;
   num_ratio_other         NUMERIC;
   num_trim                NUMERIC;
   num_trim_meas           NUMERIC;
   
BEGIN

   IF p_maximum_distance_km IS NOT NULL
   THEN
      num_ratio       := p_lengthkm / (p_tmeasure - p_fmeasure);
      num_ratio_other := p_flowtimeday / (p_tmeasure - p_fmeasure);  
      
      num_trim        := p_network_distancekm - p_maximum_distance_km;
      
   ELSIF p_maximum_flowtime_day IS NOT NULL
   THEN
      num_ratio       := p_flowtimeday / (p_tmeasure - p_fmeasure);
      num_ratio_other := p_lengthkm / (p_tmeasure - p_fmeasure);
      
      num_trim        := p_network_flowtimeday - p_maximum_flowtime_day;
      
   END IF;

   IF  num_trim > 0
   AND num_ratio > 0
   THEN
      num_trim_meas := num_trim / num_ratio;
   
      IF p_search_type IN ('UT','UM')
      THEN
         num_tmeasure := ROUND(p_tmeasure - num_trim_meas,5);
      
      ELSE
         num_fmeasure := ROUND(p_fmeasure + num_trim_meas,5);
      
      END IF;
      
      IF p_maximum_distance_km IS NOT NULL
      THEN
         num_lengthkm            := num_lengthkm - num_trim;
         num_network_distancekm  := num_network_distancekm - num_trim;
         
         num_flowtimeday         := num_flowtimeday - (num_trim_meas * num_ratio_other);
         num_network_flowtimeday := num_network_flowtimeday - (num_trim_meas * num_ratio_other);
      
      ELSIF p_maximum_flowtime_day IS NOT NULL
      THEN
         num_lengthkm            := num_lengthkm - (num_trim_meas * num_ratio_other);
         num_network_distancekm  := num_network_distancekm - (num_trim_meas * num_ratio_other);
         
         num_flowtimeday         := num_flowtimeday - num_trim;
         num_network_flowtimeday := num_network_flowtimeday - num_trim;
         
      END IF;
      
   END IF;

   RETURN QUERY SELECT
    num_fmeasure
   ,num_tmeasure
   ,num_lengthkm
   ,num_flowtimeday
   ,num_network_distancekm
   ,num_network_flowtimeday;            
   
END;
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION nhdplus_navigation30.trim_temp(
    VARCHAR
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
) OWNER TO nhdplus_navigation30;

GRANT EXECUTE ON FUNCTION nhdplus_navigation30.trim_temp(
    VARCHAR
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
   ,NUMERIC
) TO PUBLIC;


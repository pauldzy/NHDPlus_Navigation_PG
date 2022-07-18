CREATE OR REPLACE FUNCTION nhdplus_navigation30.search_type(
    IN  p_input   VARCHAR
) RETURNS VARCHAR 
IMMUTABLE
AS $BODY$ 
DECLARE
   str_input VARCHAR(2000);
   
BEGIN
   
   str_input := UPPER(p_input);
   
   IF str_input IN ('PP','POINT TO POINT','POINT-TO-POINT')
   THEN
      RETURN 'PP';
      
   ELSIF str_input IN ('PPALL')
   THEN
      RETURN 'PPALL';
   
   ELSIF str_input IN ('UT','UPSTREAM WITH TRIBUTARIES')
   THEN
      RETURN 'UT';
   
   ELSIF str_input IN ('UM','UPSTREAM MAIN PATH ONLY')
   THEN
      RETURN 'UM';
   
   ELSIF str_input IN ('DD','DOWNSTREAM WITH DIVERGENCES')
   THEN
      RETURN 'DD';
   
   ELSIF str_input IN ('DM','DOWNSTREAM MAIN PATH ONLY')
   THEN
      RETURN 'DM';
      
   END IF;
   
   RETURN NULL;
   
END;
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION nhdplus_navigation30.search_type(
   VARCHAR
) OWNER TO nhdplus_navigation30;

GRANT EXECUTE ON FUNCTION nhdplus_navigation30.search_type(
   VARCHAR
) TO PUBLIC;


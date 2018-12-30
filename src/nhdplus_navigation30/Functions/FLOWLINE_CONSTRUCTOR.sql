CREATE OR REPLACE FUNCTION nhdplus_navigation30.flowline_constructor()
RETURNS nhdplus_navigation30.flowline
STABLE
AS $BODY$ 
DECLARE 
   obj_output nhdplus_navigation30.flowline;
   
BEGIN

   obj_output := ROW(
       NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
   );
   
   RETURN obj_output;

END;
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION nhdplus_navigation30.flowline_constructor
OWNER TO nhdplus_navigation30;

GRANT EXECUTE ON FUNCTION nhdplus_navigation30.flowline_constructor
TO PUBLIC;


CREATE OR REPLACE FUNCTION nhdplus_navigation30.tests()
RETURNS BOOLEAN
AS $BODY$ 
DECLARE
   boo_results BOOLEAN;
BEGIN
   
   boo_results := TRUE;
   
   RETURN boo_results;

END;
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION nhdplus_navigation30.tests()
OWNER TO nhdplus_navigation30;

GRANT EXECUTE ON FUNCTION nhdplus_navigation30.tests()
TO PUBLIC;


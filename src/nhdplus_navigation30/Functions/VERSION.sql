CREATE OR REPLACE FUNCTION nhdplus_navigation30.version(
    OUT tfs_changeset        NUMERIC
   ,OUT jenkins_jobname      VARCHAR
   ,OUT jenkins_buildnum     NUMERIC 
   ,OUT jenkins_buildid      VARCHAR
)
AS $BODY$ 
DECLARE
BEGIN
   tfs_changeset    := 0.0;
   jenkins_jobname  := 'NULL';
   jenkins_buildnum := 0.0;
   jenkins_buildid  := 'NULL';

END;
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION nhdplus_navigation30.version()
OWNER TO nhdplus_navigation30;

GRANT EXECUTE ON FUNCTION nhdplus_navigation30.version()
TO PUBLIC;


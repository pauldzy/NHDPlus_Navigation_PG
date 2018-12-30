DROP TYPE IF EXISTS nhdplus_navigation30.flowline;

CREATE TYPE nhdplus_navigation30.flowline 
AS(
    comid                 INTEGER
   ,permanent_identifier  VARCHAR(40)
   ,reachcode             VARCHAR(14)
   ,fcode                 INTEGER
   ,fmeasure              NUMERIC
   ,tmeasure              NUMERIC
   ,hydrosequence         INTEGER
   ,levelpathid           INTEGER
   ,downhydrosequence     INTEGER
   ,dnminorhydrosequence  INTEGER
   ,uphydrosequence       INTEGER
   ,divergence            INTEGER
   ,streamlevel           INTEGER
   ,arbolatesum           NUMERIC
   ,terminalpathid        INTEGER
   ,catchment_featureid   INTEGER
   ,innetwork             VARCHAR(1)
   ,coastal               VARCHAR(1)
   ,navigable             VARCHAR(1)
   ,lengthkm              NUMERIC
   ,lengthkm_ratio        NUMERIC
   ,flowtimeday           NUMERIC
   ,flowtimeday_ratio     NUMERIC
   ,pathlengthkm          NUMERIC
   ,pathflowtimeday       NUMERIC
   ,fromnode              INTEGER
   ,tonode                INTEGER
   ,vpuid                 VARCHAR(8)
   ,out_grid_srid         INTEGER
   ,out_measure           NUMERIC
   ,out_lengthkm          NUMERIC
   ,out_flowtimeday       NUMERIC
   ,out_pathlengthkm      NUMERIC
   ,out_pathflowtimeday   NUMERIC
   ,out_node              INTEGER
);

ALTER TYPE nhdplus_navigation30.flowline OWNER TO nhdplus_navigation30;

GRANT USAGE ON TYPE nhdplus_navigation30.flowline TO PUBLIC;


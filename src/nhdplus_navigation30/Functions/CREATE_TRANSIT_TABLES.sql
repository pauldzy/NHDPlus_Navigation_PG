CREATE OR REPLACE FUNCTION nhdplus_navigation30.create_transit_tables()
RETURNS int4
VOLATILE
AS $BODY$ 
DECLARE
   str_result VARCHAR(255);
   int_check  INTEGER;
   
BEGIN
   
   DROP TABLE    IF EXISTS nhdplus_navigation30.tmp_navigation_results CASCADE;
   
   DROP TABLE    IF EXISTS nhdplus_navigation30.tmp_navigation_status CASCADE;
   
   DROP SEQUENCE IF EXISTS nhdplus_navigation30.tmp_navigation_results_seq;
   
   DROP SEQUENCE IF EXISTS nhdplus_navigation30.tmp_navigation_status_seq;
      
   CREATE UNLOGGED TABLE nhdplus_navigation30.tmp_navigation_results(
       objectid                    INTEGER     NOT NULL
      ,session_id                  VARCHAR(40) NOT NULL
      ,comid                       INTEGER     NOT NULL
      ,permanent_identifier        VARCHAR(40) NOT NULL
      ,reachcode                   VARCHAR(14) NOT NULL
      ,fmeasure                    NUMERIC     NOT NULL
      ,tmeasure                    NUMERIC     NOT NULL
      ,network_distancekm          NUMERIC
      ,network_flowtimeday         NUMERIC
      ,hydrosequence               INTEGER     NOT NULL
      ,levelpathid                 INTEGER     NOT NULL
      ,terminalpathid              INTEGER     NOT NULL
      ,uphydroseq                  INTEGER
      ,dnhydroseq                  INTEGER
      ,lengthkm                    NUMERIC     NOT NULL
      ,length_measure_ratio        NUMERIC
      ,flowtimeday                 NUMERIC
      ,flowtime_measure_ratio      NUMERIC
      ,reachsmdate                 DATE
      ,ftype                       INTEGER
      ,fcode                       INTEGER
      ,fcode_str                   VARCHAR(128)
      ,gnis_id                     VARCHAR(10)
      ,gnis_name                   VARCHAR(65)
      ,wbarea_permanent_identifier VARCHAR(40)
      ,wbarea_comid                INTEGER
      ,wbd_huc12                   VARCHAR(12)
      ,catchment_featureid         INTEGER
      ,quality_marker              INTEGER
      ,navigable                   VARCHAR(1)
      ,coastal                     VARCHAR(1)
      ,innetwork                   VARCHAR(1)
      ,navtermination_flag         INTEGER
      ,shape                       GEOMETRY
      ,nav_order                   INTEGER
      ,CONSTRAINT tmp_navigation_results_pk 
       PRIMARY KEY (session_id,comid)
       USING INDEX TABLESPACE ow_ephemeral
      ,CONSTRAINT tmp_navigation_results_pk2
       UNIQUE (session_id,permanent_identifier)
       USING INDEX TABLESPACE ow_ephemeral
   )
   TABLESPACE ow_ephemeral;
   
   ALTER TABLE nhdplus_navigation30.tmp_navigation_results OWNER TO nhdplus_navigation30;
   GRANT ALL ON TABLE nhdplus_navigation30.tmp_navigation_results TO nhdplus_navigation30;
   GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nhdplus_navigation30.tmp_navigation_results TO public;

   CREATE UNIQUE INDEX tmp_navigation_results_u01
   ON nhdplus_navigation30.tmp_navigation_results(objectid)
   TABLESPACE ow_ephemeral;

   CREATE SEQUENCE nhdplus_navigation30.tmp_navigation_results_seq 
   INCREMENT BY 1
   START WITH 1;
   
   ALTER TABLE nhdplus_navigation30.tmp_navigation_results_seq OWNER TO nhdplus_navigation30;
   GRANT USAGE,SELECT ON SEQUENCE nhdplus_navigation30.tmp_navigation_results_seq TO public;

   CREATE UNLOGGED TABLE nhdplus_navigation30.tmp_navigation_status(
       objectid                    INTEGER     NOT NULL
      ,session_id                  VARCHAR(40) NOT NULL
      ,return_code                 INTEGER
      ,status_message              VARCHAR(255)
      ,session_datestamp           TIMESTAMP
      ,CONSTRAINT tmp_navigation_status_pk 
       PRIMARY KEY (session_id)
       USING INDEX TABLESPACE ow_ephemeral
   )
   TABLESPACE ow_ephemeral;
   
   ALTER TABLE nhdplus_navigation30.tmp_navigation_status OWNER TO nhdplus_navigation30;
   GRANT ALL ON TABLE nhdplus_navigation30.tmp_navigation_status TO nhdplus_navigation30;
   GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE nhdplus_navigation30.tmp_navigation_status TO public;
   
   CREATE UNIQUE INDEX tmp_navigation_status_u01
   ON nhdplus_navigation30.tmp_navigation_status(objectid)
   TABLESPACE ow_ephemeral;
   
   CREATE SEQUENCE nhdplus_navigation30.tmp_navigation_status_seq 
   INCREMENT BY 1
   START WITH 1;
   
   ALTER TABLE nhdplus_navigation30.tmp_navigation_status_seq OWNER TO nhdplus_navigation30;
   GRANT USAGE,SELECT ON SEQUENCE nhdplus_navigation30.tmp_navigation_status_seq TO public;
   
   RETURN 0;
   
END;
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION nhdplus_navigation30.create_transit_tables() OWNER TO nhdplus_navigation30;


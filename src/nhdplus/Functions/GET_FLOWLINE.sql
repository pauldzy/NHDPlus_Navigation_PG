CREATE OR REPLACE FUNCTION nhdplus.get_flowline(
    IN     p_direction            VARCHAR DEFAULT NULL
   ,INOUT  p_comid                INTEGER DEFAULT NULL
   ,INOUT  p_permanent_identifier VARCHAR DEFAULT NULL
   ,INOUT  p_reachcode            VARCHAR DEFAULT NULL
   ,INOUT  p_hydrosequence        INTEGER DEFAULT NULL
   ,INOUT  p_measure              NUMERIC DEFAULT NULL
   ,OUT    p_fmeasure             NUMERIC
   ,OUT    p_tmeasure             NUMERIC
   ,OUT    p_lengthkm             NUMERIC
   ,OUT    p_flowtimeday          NUMERIC
   ,OUT    p_length_ratio         NUMERIC
   ,OUT    p_flowtime_ratio       NUMERIC
   ,OUT    p_node                 INTEGER
   ,OUT    p_original_pathlength  NUMERIC
   ,OUT    p_pathlength           NUMERIC
   ,OUT    p_original_pathtime    NUMERIC
   ,OUT    p_pathtime             NUMERIC
   ,OUT    p_dnminorhyd           INTEGER
   ,OUT    p_levelpathid          INTEGER
   ,OUT    p_divergence           INTEGER
   ,OUT    p_uphydroseq           INTEGER
   ,OUT    p_streamlevel          INTEGER
   ,OUT    p_arbolatesum          NUMERIC
   ,OUT    p_catchment_featureid  INTEGER
   ,OUT    p_grid_srid            INTEGER
   ,OUT    p_fcode                INTEGER
)
STABLE
AS $BODY$ 
DECLARE
   str_direction      VARCHAR(2) := UPPER(p_direction);
   num_ratio_len      NUMERIC;
   num_ratio_time     NUMERIC;
   num_difference     NUMERIC;
   int_uphydroseq     INTEGER;
   int_terminalpathid INTEGER;
   int_fromnode       INTEGER;
   int_tonode         INTEGER;
   num_end_of_line    NUMERIC := 0.0001;
   str_nhdplus_region VARCHAR(5);
   
BEGIN

   --------------------------------------------------------------------------
   -- Step 10
   -- Check over incoming parameters
   --------------------------------------------------------------------------
   IF  p_comid IS NULL
   AND p_permanent_identifier IS NULL
   AND p_reachcode IS NULL
   AND p_hydrosequence IS NULL
   THEN
      RETURN;
      
   END IF;
   
   IF str_direction IN ('UT','UM')
   THEN
      str_direction := 'U';
      
   ELSIF str_direction IN ('DD','DM','PP')
   THEN
      str_direction := 'D';
      
   END IF;
   
   IF str_direction NOT IN ('D','U')
   THEN
      str_direction := 'D';
   
   END IF;
   
   --------------------------------------------------------------------------
   -- Step 20
   -- Check when comid provided
   --------------------------------------------------------------------------
   IF p_comid IS NOT NULL
   THEN
      IF p_measure IS NULL
      THEN
         SELECT 
          a.comid
         ,a.permanent_identifier
         ,a.reachcode
         ,a.hydroseq
         ,a.fmeasure
         ,a.tmeasure
         ,a.lengthkm
         ,a.travtime
         ,a.lengthkm / (a.tmeasure - a.fmeasure)
         ,a.travtime / (a.tmeasure - a.fmeasure)
         ,a.fromnode
         ,a.tonode
         ,a.pathlength
         ,a.pathtime
         ,a.dnminorhyd
         ,a.levelpathid
         ,a.divergence
         ,a.uphydroseq
         ,a.streamlevel
         ,a.arbolatesum
         ,a.catchment_featureid
         ,a.nhdplus_region
         ,a.fcode
         INTO
          p_comid
         ,p_permanent_identifier
         ,p_reachcode
         ,p_hydrosequence
         ,p_fmeasure
         ,p_tmeasure
         ,p_lengthkm
         ,p_flowtimeday
         ,p_length_ratio
         ,p_flowtime_ratio
         ,int_fromnode
         ,int_tonode
         ,p_original_pathlength
         ,p_original_pathtime
         ,p_dnminorhyd
         ,p_levelpathid
         ,p_divergence
         ,p_uphydroseq
         ,p_streamlevel
         ,p_arbolatesum
         ,p_catchment_featureid
         ,str_nhdplus_region
         ,p_fcode
         FROM 
         nhdplus.plusflowlinevaa_np21 a
         WHERE
         a.comid = p_comid;
         
         IF str_direction = 'D'
         THEN
            p_measure    := p_tmeasure;
            p_node       := int_tonode;
            p_pathlength := p_original_pathlength + p_lengthkm;
            p_pathtime   := p_original_pathtime   + p_flowtimeday;
      
         ELSIF str_direction = 'U'
         THEN  
            p_measure    := p_fmeasure;
            p_node       := int_fromnode;
            p_pathlength := p_original_pathlength;
            p_pathtime   := p_original_pathtime;
      
         END IF;
         
      ELSE
         SELECT 
          a.comid
         ,a.permanent_identifier
         ,a.reachcode
         ,a.hydroseq
         ,a.fmeasure
         ,a.tmeasure
         ,a.lengthkm
         ,a.travtime
         ,a.lengthkm / (a.tmeasure - a.fmeasure)
         ,a.travtime / (a.tmeasure - a.fmeasure)
         ,a.uphydroseq
         ,a.terminalpathid
         ,a.fromnode
         ,a.tonode
         ,a.pathlength
         ,a.pathtime
         ,a.dnminorhyd
         ,a.levelpathid
         ,a.divergence
         ,a.uphydroseq
         ,a.streamlevel
         ,a.arbolatesum
         ,a.catchment_featureid
         ,a.nhdplus_region
         ,a.fcode
         INTO
          p_comid
         ,p_permanent_identifier
         ,p_reachcode
         ,p_hydrosequence
         ,p_fmeasure
         ,p_tmeasure
         ,p_lengthkm
         ,p_flowtimeday
         ,p_length_ratio
         ,p_flowtime_ratio
         ,int_uphydroseq
         ,int_terminalpathid
         ,int_fromnode
         ,int_tonode
         ,p_original_pathlength
         ,p_original_pathtime 
         ,p_dnminorhyd
         ,p_levelpathid
         ,p_divergence
         ,p_uphydroseq
         ,p_streamlevel
         ,p_arbolatesum
         ,p_catchment_featureid
         ,str_nhdplus_region
         ,p_fcode
         FROM 
         nhdplus.plusflowlinevaa_np21 a
         WHERE
         a.comid = p_comid
         AND (
            a.fmeasure = p_measure
            OR
            (a.fmeasure < p_measure AND a.tmeasure >= p_measure)
         );
         
         IF str_direction = 'D'
         THEN
            IF  p_measure = p_fmeasure
            AND p_hydrosequence = int_terminalpathid
            THEN
               p_measure := p_fmeasure + num_end_of_line;
            
            END IF;
            
            num_difference := p_measure - p_fmeasure;
            p_node := int_tonode;
            
            p_lengthkm    := num_difference * p_length_ratio;
            p_flowtimeday := num_difference * p_flowtime_ratio;
            
            p_pathlength := p_original_pathlength + p_lengthkm;
            p_pathtime   := p_original_pathtime   + p_flowtimeday;
            
         ELSIF str_direction = 'U'
         THEN  
            IF p_measure = p_tmeasure
            AND int_uphydroseq = 0
            THEN
               p_measure := p_tmeasure - num_end_of_line;
            
            END IF;
            
            num_difference := p_tmeasure - p_measure;
            p_node := int_fromnode;
            
            p_lengthkm    := num_difference * p_length_ratio;
            p_flowtimeday := num_difference * p_flowtime_ratio;
            
            p_pathlength := p_original_pathlength + (( 100 - num_difference ) * p_length_ratio);
            p_pathtime   := p_original_pathtime   + (( 100 - num_difference ) * p_flowtime_ratio);
      
         ELSE
            RAISE EXCEPTION 'err';
            
         END IF;       
      
      END IF;   
   
   --------------------------------------------------------------------------
   -- Step 30
   -- Check when permanent_identifier provided
   --------------------------------------------------------------------------
   ELSIF p_permanent_identifier IS NOT NULL
   THEN
      IF p_measure IS NULL
      THEN
         SELECT 
          a.comid
         ,a.permanent_identifier
         ,a.reachcode
         ,a.hydroseq
         ,a.fmeasure
         ,a.tmeasure
         ,a.lengthkm
         ,a.travtime
         ,a.lengthkm / (a.tmeasure - a.fmeasure)
         ,a.travtime / (a.tmeasure - a.fmeasure)
         ,a.fromnode
         ,a.tonode
         ,a.pathlength
         ,a.pathtime
         ,a.dnminorhyd
         ,a.levelpathid
         ,a.divergence
         ,a.uphydroseq
         ,a.streamlevel
         ,a.arbolatesum
         ,a.catchment_featureid
         ,a.nhdplus_region
         ,a.fcode
         INTO
          p_comid
         ,p_permanent_identifier
         ,p_reachcode
         ,p_hydrosequence
         ,p_fmeasure
         ,p_tmeasure
         ,p_lengthkm
         ,p_flowtimeday
         ,p_length_ratio
         ,p_flowtime_ratio
         ,int_fromnode
         ,int_tonode
         ,p_original_pathlength
         ,p_original_pathtime
         ,p_dnminorhyd
         ,p_levelpathid
         ,p_divergence
         ,p_uphydroseq
         ,p_streamlevel
         ,p_arbolatesum
         ,p_catchment_featureid
         ,str_nhdplus_region
         ,p_fcode
         FROM 
         nhdplus.plusflowlinevaa_np21 a
         WHERE
         a.permanent_identifier = p_permanent_identifier;
         
         IF str_direction = 'D'
         THEN
            p_measure := p_tmeasure;
            p_node    := int_tonode;
            
            p_pathlength := p_original_pathlength + p_lengthkm;
            p_pathtime   := p_original_pathtime   + p_flowtimeday;
      
         ELSIF str_direction = 'U'
         THEN  
            p_measure := p_fmeasure;
            p_node    := int_fromnode;
            
            p_pathlength := p_original_pathlength;
            p_pathtime   := p_original_pathtime;
      
         END IF;
         
      ELSE
         SELECT 
          a.comid
         ,a.permanent_identifier
         ,a.reachcode
         ,a.hydroseq
         ,a.fmeasure
         ,a.tmeasure
         ,a.lengthkm
         ,a.travtime
         ,a.lengthkm / (a.tmeasure - a.fmeasure)
         ,a.travtime / (a.tmeasure - a.fmeasure)
         ,a.uphydroseq
         ,a.terminalpathid
         ,a.fromnode
         ,a.tonode
         ,a.pathlength
         ,a.pathtime
         ,a.dnminorhyd
         ,a.levelpathid
         ,a.divergence
         ,a.uphydroseq
         ,a.streamlevel
         ,a.arbolatesum
         ,a.catchment_featureid
         ,a.nhdplus_region
         ,a.fcode
         INTO
          p_comid
         ,p_permanent_identifier
         ,p_reachcode
         ,p_hydrosequence
         ,p_fmeasure
         ,p_tmeasure
         ,p_lengthkm
         ,p_flowtimeday
         ,p_length_ratio
         ,p_flowtime_ratio
         ,int_uphydroseq
         ,int_terminalpathid
         ,int_fromnode
         ,int_tonode
         ,p_original_pathlength
         ,p_original_pathtime
         ,p_dnminorhyd
         ,p_levelpathid
         ,p_divergence
         ,p_uphydroseq
         ,p_streamlevel
         ,p_arbolatesum
         ,p_catchment_featureid
         ,str_nhdplus_region
         ,p_fcode
         FROM 
         nhdplus.plusflowlinevaa_np21 a
         WHERE
         a.permanent_identifier = p_permanent_identifier
         AND (
            a.fmeasure = p_measure
            OR
            (a.fmeasure < p_measure AND a.tmeasure >= p_measure)
         );
         
         IF str_direction = 'D'
         THEN
            IF  p_measure = p_fmeasure
            AND p_hydrosequence = int_terminalpathid
            THEN
               p_measure := p_fmeasure + num_end_of_line;
            
            END IF;
            
            num_difference := p_measure - p_fmeasure;
            p_node := int_tonode;
            
            p_lengthkm    := num_difference * p_length_ratio;
            p_flowtimeday := num_difference * p_flowtime_ratio;
            
            p_pathlength := p_original_pathlength + p_lengthkm;
            p_pathtime   := p_original_pathtime   + p_flowtimeday;
            
         ELSIF str_direction = 'U'
         THEN
            IF p_measure = p_tmeasure
            AND int_uphydroseq = 0
            THEN
               p_measure := p_tmeasure - num_end_of_line;
            
            END IF;
            
            num_difference := p_tmeasure - p_measure;
            p_node := int_fromnode;
            
            p_lengthkm    := num_difference * p_length_ratio;
            p_flowtimeday := num_difference * p_flowtime_ratio;
            
            p_pathlength := p_original_pathlength + (( 100 - num_difference ) * p_length_ratio);
            p_pathtime   := p_original_pathtime   + (( 100 - num_difference ) * p_flowtime_ratio);
      
         END IF;
  
      END IF; 
   
   --------------------------------------------------------------------------
   -- Step 40
   -- Check when reach code provided
   --------------------------------------------------------------------------
   ELSIF p_reachcode IS NOT NULL
   THEN
      IF p_measure IS NULL
      THEN
         IF str_direction = 'D'
         THEN
            SELECT 
             a.comid
            ,a.permanent_identifier
            ,a.reachcode
            ,a.hydroseq
            ,a.fmeasure
            ,a.tmeasure
            ,a.lengthkm
            ,a.travtime
            ,a.lengthkm / (a.tmeasure - a.fmeasure)
            ,a.travtime / (a.tmeasure - a.fmeasure)
            ,a.fromnode
            ,a.tonode
            ,a.pathlength
            ,a.pathtime
            ,a.dnminorhyd
            ,a.levelpathid
            ,a.divergence
            ,a.uphydroseq
            ,a.streamlevel
            ,a.arbolatesum
            ,a.catchment_featureid
            ,a.nhdplus_region
            ,a.fcode
            INTO
             p_comid
            ,p_permanent_identifier
            ,p_reachcode
            ,p_hydrosequence
            ,p_fmeasure
            ,p_tmeasure
            ,p_lengthkm
            ,p_flowtimeday
            ,p_length_ratio
            ,p_flowtime_ratio
            ,int_fromnode
            ,int_tonode
            ,p_original_pathlength
            ,p_original_pathtime
            ,p_dnminorhyd
            ,p_levelpathid
            ,p_divergence
            ,p_uphydroseq
            ,p_streamlevel
            ,p_arbolatesum
            ,p_catchment_featureid
            ,str_nhdplus_region
            ,p_fcode
            FROM
            nhdplus.plusflowlinevaa_np21 a
            WHERE 
                a.reachcode = p_reachcode 
            AND a.tmeasure = 100;
            
            p_measure := 100;
            p_node    := int_tonode;
            
            p_pathlength := p_original_pathlength + p_lengthkm;
            p_pathtime   := p_original_pathtime   + p_flowtimeday;
            
         ELSE
            SELECT 
             a.comid
            ,a.permanent_identifier
            ,a.reachcode
            ,a.hydroseq
            ,a.fmeasure
            ,a.tmeasure
            ,a.lengthkm
            ,a.travtime
            ,a.lengthkm / (a.tmeasure - a.fmeasure)
            ,a.travtime / (a.tmeasure - a.fmeasure)
            ,a.fromnode
            ,a.tonode
            ,a.pathlength
            ,a.pathtime
            ,a.dnminorhyd
            ,a.levelpathid
            ,a.divergence
            ,a.uphydroseq
            ,a.streamlevel
            ,a.arbolatesum
            ,a.catchment_featureid
            ,a.nhdplus_region
            ,a.fcode
            INTO
             p_comid
            ,p_permanent_identifier
            ,p_reachcode
            ,p_hydrosequence
            ,p_fmeasure
            ,p_tmeasure
            ,p_lengthkm
            ,p_flowtimeday
            ,p_length_ratio
            ,p_flowtime_ratio
            ,int_fromnode
            ,int_tonode
            ,p_original_pathlength
            ,p_original_pathtime
            ,p_dnminorhyd
            ,p_levelpathid
            ,p_divergence
            ,p_uphydroseq
            ,p_streamlevel
            ,p_arbolatesum
            ,p_catchment_featureid
            ,str_nhdplus_region
            ,p_fcode
            FROM
            nhdplus.plusflowlinevaa_np21 a
            WHERE 
                a.reachcode = p_reachcode 
            AND a.fmeasure = 0;
         
            p_measure := 0;
            p_node    := int_fromnode;
            
            p_pathlength := p_original_pathlength;
            p_pathtime   := p_original_pathtime;
         
         END IF;
         
      ELSE
         SELECT 
          a.comid
         ,a.permanent_identifier
         ,a.reachcode
         ,a.hydroseq
         ,a.fmeasure
         ,a.tmeasure
         ,a.lengthkm
         ,a.travtime
         ,a.lengthkm / (a.tmeasure - a.fmeasure)
         ,a.travtime / (a.tmeasure - a.fmeasure)
         ,a.uphydroseq
         ,a.terminalpathid
         ,a.fromnode
         ,a.tonode
         ,a.pathlength
         ,a.pathtime
         ,a.dnminorhyd
         ,a.levelpathid
         ,a.divergence
         ,a.uphydroseq
         ,a.streamlevel
         ,a.arbolatesum
         ,a.catchment_featureid
         ,a.nhdplus_region
         ,a.fcode
         INTO
          p_comid
         ,p_permanent_identifier
         ,p_reachcode
         ,p_hydrosequence
         ,p_fmeasure
         ,p_tmeasure
         ,p_lengthkm
         ,p_flowtimeday
         ,p_length_ratio
         ,p_flowtime_ratio
         ,int_uphydroseq
         ,int_terminalpathid
         ,int_fromnode
         ,int_tonode
         ,p_original_pathlength
         ,p_original_pathtime
         ,p_dnminorhyd
         ,p_levelpathid
         ,p_divergence
         ,p_uphydroseq
         ,p_streamlevel
         ,p_arbolatesum
         ,p_catchment_featureid
         ,str_nhdplus_region
         ,p_fcode
         FROM
         nhdplus.plusflowlinevaa_np21 a
         JOIN
         nhdplus.nhdflowline_np21 b
         ON
         a.permanent_identifier = b.permanent_identifier
         WHERE 
             b.reachcode = p_reachcode 
         AND (
            (p_measure = 0 AND a.fmeasure = 0)
            OR
            (a.fmeasure < p_measure AND a.tmeasure >= p_measure)
         );
         
         IF str_direction = 'D'
         THEN
            IF  p_measure = p_fmeasure
            AND p_hydrosequence = int_terminalpathid
            THEN
               p_measure := p_fmeasure + num_end_of_line;
            
            END IF;
            
            num_difference := p_measure - p_fmeasure;
            p_node         := int_tonode;
            
            p_lengthkm    := num_difference * p_length_ratio;
            p_flowtimeday := num_difference * p_flowtime_ratio;
            
            p_pathlength := p_original_pathlength + p_lengthkm;
            p_pathtime   := p_original_pathtime   + p_flowtimeday;
            
         ELSIF str_direction = 'U'
         THEN
            IF p_measure = p_tmeasure
            AND int_uphydroseq = 0
            THEN
               p_measure := p_tmeasure - num_end_of_line;
            
            END IF;
            
            num_difference := p_tmeasure - p_measure;
            p_node         := int_fromnode;
            
            p_lengthkm    := num_difference * p_length_ratio;
            p_flowtimeday := num_difference * p_flowtime_ratio;
            
            p_pathlength := p_original_pathlength + (( 100 - num_difference ) * p_length_ratio);
            p_pathtime   := p_original_pathtime   + (( 100 - num_difference ) * p_flowtime_ratio);
      
         END IF;
 
      END IF;
    
   --------------------------------------------------------------------------
   -- Step 50
   -- Check when reach code provided
   --------------------------------------------------------------------------
   ELSIF p_hydrosequence IS NOT NULL
   THEN
      IF p_measure IS NULL
      THEN
         SELECT 
          a.comid
         ,a.permanent_identifier
         ,a.reachcode
         ,a.hydroseq
         ,a.fmeasure
         ,a.tmeasure
         ,a.lengthkm
         ,a.travtime
         ,a.lengthkm / (a.tmeasure - a.fmeasure)
         ,a.travtime / (a.tmeasure - a.fmeasure)
         ,a.fromnode
         ,a.tonode
         ,a.pathlength
         ,a.pathtime
         ,a.dnminorhyd
         ,a.levelpathid
         ,a.divergence
         ,a.uphydroseq
         ,a.streamlevel
         ,a.arbolatesum
         ,a.catchment_featureid
         ,a.nhdplus_region
         ,a.fcode
         INTO
          p_comid
         ,p_permanent_identifier
         ,p_reachcode
         ,p_hydrosequence
         ,p_fmeasure
         ,p_tmeasure
         ,p_lengthkm
         ,p_flowtimeday
         ,p_length_ratio
         ,p_flowtime_ratio
         ,int_fromnode
         ,int_tonode
         ,p_original_pathlength
         ,p_original_pathtime 
         ,p_dnminorhyd
         ,p_levelpathid
         ,p_divergence
         ,p_uphydroseq
         ,p_streamlevel
         ,p_arbolatesum
         ,p_catchment_featureid
         ,str_nhdplus_region
         ,p_fcode
         FROM 
         nhdplus.plusflowlinevaa_np21 a
         WHERE
         a.hydroseq = p_hydrosequence;
         
         IF str_direction = 'D'
         THEN
            p_measure := p_tmeasure;
            p_node    := int_tonode;
            
            p_pathlength := p_original_pathlength + p_lengthkm;
            p_pathtime   := p_original_pathtime   + p_flowtimeday;
      
         ELSIF str_direction = 'U'
         THEN  
            p_measure := p_fmeasure;
            p_node    := int_fromnode;
            
            p_pathlength := p_original_pathlength;
            p_pathtime   := p_original_pathtime;
      
         END IF;
         
      ELSE
         SELECT 
          a.comid
         ,a.permanent_identifier
         ,a.reachcode
         ,a.hydroseq
         ,a.fmeasure
         ,a.tmeasure
         ,a.lengthkm
         ,a.travtime
         ,a.lengthkm / (a.tmeasure - a.fmeasure)
         ,a.travtime / (a.tmeasure - a.fmeasure)
         ,a.uphydroseq
         ,a.terminalpathid
         ,a.fromnode
         ,a.tonode
         ,a.pathlength
         ,a.pathtime
         ,a.dnminorhyd
         ,a.levelpathid
         ,a.divergence
         ,a.uphydroseq
         ,a.streamlevel
         ,a.arbolatesum
         ,a.catchment_featureid
         ,a.nhdplus_region
         ,a.fcode
         INTO
          p_comid
         ,p_permanent_identifier
         ,p_reachcode
         ,p_hydrosequence
         ,p_fmeasure
         ,p_tmeasure
         ,p_lengthkm
         ,p_flowtimeday
         ,p_length_ratio
         ,p_flowtime_ratio
         ,int_uphydroseq
         ,int_terminalpathid
         ,int_fromnode
         ,int_tonode
         ,p_original_pathlength
         ,p_original_pathtime
         ,p_dnminorhyd
         ,p_levelpathid
         ,p_divergence
         ,p_uphydroseq
         ,p_streamlevel
         ,p_arbolatesum
         ,p_catchment_featureid
         ,str_nhdplus_region
         ,p_fcode
         FROM 
         nhdplus.plusflowlinevaa_np21 a
         WHERE
         a.hydroseq = p_hydrosequence
         AND (
            a.fmeasure = p_measure
            OR
            (a.fmeasure < p_measure AND a.tmeasure >= p_measure)
         );      
         
         IF str_direction = 'D'
         THEN
            IF  p_measure = p_fmeasure
            AND p_hydrosequence = int_terminalpathid
            THEN
               p_measure := p_fmeasure + num_end_of_line;
            
            END IF;
            
            num_difference := p_measure - p_fmeasure;
            p_node         := int_tonode;
            
            p_lengthkm    := num_difference * p_length_ratio;
            p_flowtimeday := num_difference * p_flowtime_ratio;
            
            p_pathlength := p_original_pathlength + p_lengthkm;
            p_pathtime   := p_original_pathtime   + p_flowtimeday;
            
         ELSIF str_direction = 'U'
         THEN
            IF p_measure = p_tmeasure
            AND int_uphydroseq = 0
            THEN
               p_measure := p_tmeasure - num_end_of_line;
            
            END IF;
            
            num_difference := p_tmeasure - p_measure;
            p_node         := int_fromnode;
            
            p_lengthkm    := num_difference * p_length_ratio;
            p_flowtimeday := num_difference * p_flowtime_ratio;
            
            p_pathlength := p_original_pathlength + (( 100 - num_difference ) * p_length_ratio);
            p_pathtime   := p_original_pathtime   + (( 100 - num_difference ) * p_flowtime_ratio);
      
         END IF;
         
      END IF;  
      
   END IF;
   
   --------------------------------------------------------------------------
   -- Step 50
   -- Determine grid srid
   --------------------------------------------------------------------------
   IF str_nhdplus_region = '20'
   THEN
      p_grid_srid := 26904;
      
   ELSIF str_nhdplus_region = '21'
   THEN
      p_grid_srid := 32161;
      
   ELSIF str_nhdplus_region IN ('22G','22M')
   THEN
      p_grid_srid := 32655;
      
   ELSIF str_nhdplus_region = '22A'
   THEN
      p_grid_srid := 32702;
   
   ELSE
      p_grid_srid := 5070;
      
   END IF;
   
END;
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION nhdplus.get_flowline(
    VARCHAR
   ,INTEGER
   ,VARCHAR
   ,VARCHAR
   ,INTEGER
   ,NUMERIC
) OWNER TO nhdplus;

GRANT EXECUTE ON FUNCTION nhdplus.get_flowline(
    VARCHAR
   ,INTEGER
   ,VARCHAR
   ,VARCHAR
   ,INTEGER
   ,NUMERIC
) TO PUBLIC;


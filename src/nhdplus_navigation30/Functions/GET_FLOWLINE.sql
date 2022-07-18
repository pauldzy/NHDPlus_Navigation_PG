CREATE OR REPLACE FUNCTION nhdplus_navigation30.get_flowline(
    IN  p_direction            VARCHAR DEFAULT NULL
   ,IN  p_comid                INTEGER DEFAULT NULL
   ,IN  p_permanent_identifier VARCHAR DEFAULT NULL
   ,IN  p_reachcode            VARCHAR DEFAULT NULL
   ,IN  p_hydrosequence        INTEGER DEFAULT NULL
   ,IN  p_measure              NUMERIC DEFAULT NULL
   ,OUT p_flowline             nhdplus_navigation30.flowline
   ,OUT p_return_code          INTEGER
   ,OUT p_status_message       VARCHAR
)
STABLE
AS $BODY$ 
DECLARE
   str_direction      VARCHAR(5) := UPPER(p_direction);
   num_difference     NUMERIC;
   num_end_of_line    NUMERIC := 0.0001;
   
BEGIN

   --------------------------------------------------------------------------
   -- Step 10
   -- Check over incoming parameters
   --------------------------------------------------------------------------
   p_return_code := 0;
   
   IF  p_comid IS NULL
   AND p_permanent_identifier IS NULL
   AND p_reachcode IS NULL
   AND p_hydrosequence IS NULL
   THEN
      p_return_code    := -2;
      p_status_message := 'ComID, Permanent Identifier, Reach Code or Hydrosequence value is required.';
      RETURN;
      
   END IF;
   
   IF str_direction IN ('UT','UM')
   THEN
      str_direction := 'U';
      
   ELSIF str_direction IN ('DD','DM','PP','PPALL')
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
   IF p_comid                IS NOT NULL
   OR p_permanent_identifier IS NOT NULL
   OR p_hydrosequence        IS NOT NULL
   THEN
      IF p_measure IS NULL
      THEN
         SELECT 
          a.comid
         ,a.permanent_identifier
         ,a.reachcode
         ,a.fcode
         ,a.fmeasure
         ,a.tmeasure
         ,b.hydroseq
         ,b.levelpathid
         ,b.dnhydroseq
         ,b.dnminorhyd
         ,b.uphydroseq
         ,b.divergence
         ,b.streamlevel
         ,b.arbolatesum
         ,b.terminalpathid
         ,a.catchment_featureid
         ,a.innetwork
         ,a.coastal
         ,a.navigable
         ,a.lengthkm
         ,a.lengthkm / (a.tmeasure - a.fmeasure)
         ,a.flowtimeday
         ,a.flowtimeday / (a.tmeasure - a.fmeasure)
         ,b.pathlength
         ,b.pathtimema
         ,b.fromnode
         ,b.tonode
         ,a.vpuid
         ,NULL
         ,NULL
         ,NULL
         ,NULL
         ,NULL
         ,NULL
         INTO STRICT
         p_flowline
         FROM 
         nhdplus.nhdflowline_np21 a
         LEFT JOIN
         nhdplus.plusflowlinevaa_np21 b
         ON
         a.comid = b.comid
         WHERE
            a.comid                = p_comid
         OR a.permanent_identifier = p_permanent_identifier
         OR a.hydroseq             = p_hydrosequence;

         p_flowline.out_lengthkm           := p_flowline.lengthkm;
         p_flowline.out_flowtimeday        := p_flowline.flowtimeday;
         
         IF str_direction = 'D'
         THEN
            p_flowline.out_measure         := p_flowline.tmeasure;
            p_flowline.out_node            := p_flowline.tonode;
            p_flowline.out_pathlengthkm    := p_flowline.pathlengthkm + p_flowline.lengthkm;
            p_flowline.out_pathflowtimeday := p_flowline.pathflowtimeday  + p_flowline.flowtimeday;
      
         ELSIF str_direction = 'U'
         THEN  
            p_flowline.out_measure         := p_flowline.fmeasure;
            p_flowline.out_node            := p_flowline.fromnode;
            p_flowline.out_pathlengthkm    := p_flowline.pathlengthkm;
            p_flowline.out_pathflowtimeday := p_flowline.pathflowtimeday;
      
         END IF;
         
      ELSE
         SELECT 
          a.comid
         ,a.permanent_identifier
         ,a.reachcode
         ,a.fcode
         ,a.fmeasure
         ,a.tmeasure
         ,b.hydroseq
         ,b.levelpathid
         ,b.dnhydroseq
         ,b.dnminorhyd
         ,b.uphydroseq
         ,b.divergence
         ,b.streamlevel
         ,b.arbolatesum
         ,b.terminalpathid
         ,a.catchment_featureid
         ,a.innetwork
         ,a.coastal
         ,a.navigable
         ,a.lengthkm
         ,a.lengthkm / (a.tmeasure - a.fmeasure)
         ,a.flowtimeday
         ,a.flowtimeday / (a.tmeasure - a.fmeasure)
         ,b.pathlength
         ,b.pathtimema 
         ,b.fromnode
         ,b.tonode
         ,a.vpuid
         ,NULL
         ,NULL
         ,NULL
         ,NULL
         ,NULL
         ,NULL
         INTO STRICT
         p_flowline
         FROM 
         nhdplus.nhdflowline_np21 a
         LEFT JOIN
         nhdplus.plusflowlinevaa_np21 b
         ON
         a.comid = b.comid
         WHERE (
               a.comid                = p_comid
            OR a.permanent_identifier = p_permanent_identifier
            OR a.hydroseq             = p_hydrosequence
         ) AND (
            a.fmeasure = p_measure
            OR
            (a.fmeasure < p_measure AND a.tmeasure >= p_measure)
         );
         
         p_flowline.out_measure := p_measure;
         
         IF str_direction = 'D'
         THEN
            IF  p_measure = p_flowline.fmeasure
            AND p_flowline.hydrosequence = p_flowline.terminalpathid
            THEN
               p_flowline.out_measure := p_flowline.fmeasure + num_end_of_line;
            
            END IF;
            
            num_difference                 := p_flowline.out_measure - p_flowline.fmeasure;
            p_flowline.out_node            := p_flowline.tonode;
            
            p_flowline.out_lengthkm        := num_difference * p_flowline.lengthkm_ratio;
            p_flowline.out_flowtimeday     := num_difference * p_flowline.flowtimeday_ratio;
            
            p_flowline.out_pathlengthkm    := p_flowline.pathlengthkm + p_flowline.lengthkm;
            p_flowline.out_pathflowtimeday := p_flowline.pathflowtimeday  + p_flowline.flowtimeday;
            
         ELSIF str_direction = 'U'
         THEN  
            IF p_measure = p_flowline.tmeasure
            AND p_flowline.uphydrosequence = 0
            THEN
               p_flowline.out_measure := p_flowline.tmeasure - num_end_of_line;
            
            END IF;
            
            num_difference                 := p_flowline.tmeasure - p_flowline.out_measure;
            p_flowline.out_node            := p_flowline.fromnode;
            
            p_flowline.out_lengthkm        := num_difference * p_flowline.lengthkm_ratio;
            p_flowline.out_flowtimeday     := num_difference * p_flowline.flowtimeday_ratio;
            
            p_flowline.out_pathlengthkm    := p_flowline.pathlengthkm + (( 100 - num_difference ) * p_flowline.lengthkm_ratio);
            p_flowline.out_pathflowtimeday := p_flowline.pathflowtimeday  + (( 100 - num_difference ) * p_flowline.flowtimeday_ratio);
      
         ELSE
            RAISE EXCEPTION 'err';
            
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
         SELECT 
          a.comid
         ,a.permanent_identifier
         ,a.reachcode
         ,a.fcode
         ,a.fmeasure
         ,a.tmeasure
         ,b.hydroseq
         ,b.levelpathid
         ,b.dnhydroseq
         ,b.dnminorhyd
         ,b.uphydroseq
         ,b.divergence
         ,b.streamlevel
         ,b.arbolatesum
         ,b.terminalpathid
         ,a.catchment_featureid
         ,a.innetwork
         ,a.coastal
         ,a.navigable
         ,a.lengthkm
         ,a.lengthkm / (a.tmeasure - a.fmeasure)
         ,a.flowtimeday
         ,a.flowtimeday / (a.tmeasure - a.fmeasure)
         ,b.pathlength
         ,b.pathtimema 
         ,b.fromnode
         ,b.tonode
         ,a.vpuid
         ,NULL
         ,NULL
         ,NULL
         ,NULL
         ,NULL
         ,NULL
         INTO STRICT
         p_flowline
         FROM 
         nhdplus.nhdflowline_np21 a
         LEFT JOIN
         nhdplus.plusflowlinevaa_np21 b
         ON
         a.comid = b.comid
         WHERE 
             a.reachcode = p_reachcode 
         AND (
               (str_direction = 'D' AND a.tmeasure = 100)
            OR (str_direction = 'U' AND a.fmeasure = 0 )
         );
         
         p_flowline.out_lengthkm           := p_flowline.lengthkm;
         p_flowline.out_flowtimeday        := p_flowline.flowtimeday;
         
         IF str_direction = 'D'
         THEN
            p_flowline.out_measure         := 100;
            p_flowline.out_node            := p_flowline.tonode;
            
            p_flowline.out_pathlengthkm    := p_flowline.pathlengthkm + p_flowline.lengthkm;
            p_flowline.out_pathflowtimeday := p_flowline.pathflowtimeday  + p_flowline.flowtimeday;
            
         ELSIF str_direction = 'U'
         THEN
            p_flowline.out_measure         := 0;
            p_flowline.out_node            := p_flowline.fromnode;
            
            p_flowline.out_pathlengthkm    := p_flowline.pathlengthkm;
            p_flowline.out_pathflowtimeday := p_flowline.pathflowtimeday;
         
         ELSE
            RAISE EXCEPTION 'err';
            
         END IF;
         
      ELSE
         SELECT 
          a.comid
         ,a.permanent_identifier
         ,a.reachcode
         ,a.fcode
         ,a.fmeasure
         ,a.tmeasure
         ,b.hydroseq
         ,b.levelpathid
         ,b.dnhydroseq
         ,b.dnminorhyd
         ,b.uphydroseq
         ,b.divergence
         ,b.streamlevel
         ,b.arbolatesum
         ,b.terminalpathid
         ,a.catchment_featureid
         ,a.innetwork
         ,a.coastal
         ,a.navigable
         ,a.lengthkm
         ,a.lengthkm / (a.tmeasure - a.fmeasure)
         ,a.flowtimeday
         ,a.flowtimeday / (a.tmeasure - a.fmeasure)
         ,b.pathlength
         ,b.pathtimema
         ,b.fromnode
         ,b.tonode
         ,a.vpuid
         ,NULL
         ,NULL
         ,NULL
         ,NULL
         ,NULL
         ,NULL
         INTO STRICT
         p_flowline
         FROM 
         nhdplus.nhdflowline_np21 a
         LEFT JOIN
         nhdplus.plusflowlinevaa_np21 b
         ON
         a.comid = b.comid
         WHERE 
             a.reachcode = p_reachcode 
         AND (
            (p_measure = 0 AND a.fmeasure = 0)
            OR
            (a.fmeasure < p_measure AND a.tmeasure >= p_measure)
         );
         
         p_flowline.out_measure := p_measure;
         
         IF str_direction = 'D'
         THEN
            IF  p_measure = p_flowline.fmeasure
            AND p_flowline.hydrosequence = p_flowline.terminalpathid
            THEN
               p_flowline.out_measure := p_flowline.fmeasure + num_end_of_line;
            
            END IF;
            
            num_difference                 := p_measure - p_flowline.fmeasure;
            p_flowline.out_node            := p_flowline.tonode;
            
            p_flowline.out_lengthkm        := num_difference * p_flowline.lengthkm_ratio;
            p_flowline.out_flowtimeday     := num_difference * p_flowline.flowtimeday_ratio;
            
            p_flowline.out_pathlengthkm    := p_flowline.pathlengthkm + p_flowline.lengthkm;
            p_flowline.out_pathflowtimeday := p_flowline.pathflowtimeday  + p_flowline.flowtimeday;
            
         ELSIF str_direction = 'U'
         THEN
            IF p_measure = p_flowline.tmeasure
            AND p_flowline.uphydrosequence = 0
            THEN
               p_flowline.out_measure := p_flowline.tmeasure - num_end_of_line;
            
            END IF;
            
            num_difference                 := p_flowline.tmeasure - p_measure;
            p_flowline.out_node            := p_flowline.fromnode;
            
            p_flowline.out_lengthkm        := num_difference * p_flowline.lengthkm_ratio;
            p_flowline.out_flowtimeday     := num_difference * p_flowline.flowtimeday_ratio;
            
            p_flowline.out_pathlengthkm    := p_flowline.pathlengthkm + (( 100 - num_difference ) * p_flowline.lengthkm_ratio);
            p_flowline.out_pathflowtimeday := p_flowline.pathflowtimeday  + (( 100 - num_difference ) * p_flowline.flowtimeday_ratio);
      
         ELSE
            RAISE EXCEPTION 'err';
            
         END IF;
 
      END IF;
    
   END IF;
   
   --------------------------------------------------------------------------
   -- Step 50
   -- Determine grid srid
   --------------------------------------------------------------------------
   IF p_flowline.vpuid = '20'
   THEN
      p_flowline.out_grid_srid := 26904;
      
   ELSIF p_flowline.vpuid = '21'
   THEN
      p_flowline.out_grid_srid := 32161;
      
   ELSIF p_flowline.vpuid IN ('22G','22M')
   THEN
      p_flowline.out_grid_srid := 32655;
      
   ELSIF p_flowline.vpuid = '22A'
   THEN
      p_flowline.out_grid_srid := 32702;
   
   ELSE
      p_flowline.out_grid_srid := 5070;
      
   END IF;
   
EXCEPTION

   WHEN NO_DATA_FOUND
   THEN
      p_return_code    := -10;
      p_status_message := 'no results found in NHDPlus';
      RETURN;

   WHEN OTHERS
   THEN
      RAISE;   

END;
$BODY$
LANGUAGE plpgsql;

ALTER FUNCTION nhdplus_navigation30.get_flowline(
    VARCHAR
   ,INTEGER
   ,VARCHAR
   ,VARCHAR
   ,INTEGER
   ,NUMERIC
) OWNER TO nhdplus_navigation30;

GRANT EXECUTE ON FUNCTION nhdplus_navigation30.get_flowline(
    VARCHAR
   ,INTEGER
   ,VARCHAR
   ,VARCHAR
   ,INTEGER
   ,NUMERIC
) TO PUBLIC;


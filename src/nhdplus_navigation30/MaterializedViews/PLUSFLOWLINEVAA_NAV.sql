DROP MATERIALIZED VIEW nhdplus_navigation30.plusflowlinevaa_nav;

CREATE MATERIALIZED VIEW nhdplus_navigation30.plusflowlinevaa_nav(
    comid
   ,hydroseq
   ,levelpathid
   ,divergence
   ,fmeasure
   ,tmeasure
   ,lengthkm
   ,totma
   ,pathlength
   ,pathtimema
   ,uphydroseq
   ,dnhydroseq
   ,dnminorhyd
   ,terminalpathid
   ,fromnode
   ,tonode
   ,force_main_line
   ,ary_upstream_hydroseq
   ,ary_downstream_hydroseq
   ,headwater
   ,coastal_connection
)
TABLESPACE nhdplus_data
AS
SELECT
 a.comid
,a.hydroseq
,a.levelpathid
,a.divergence
,a.fmeasure
,a.tmeasure
,a.lengthkm
,a.totma
,a.pathlength
,a.pathtimema
,CASE
 WHEN a.uphydroseq = 0
 THEN
   NULL
 ELSE
   a.uphydroseq
 END AS uphydroseq
,CASE
 WHEN a.dnhydroseq = 0
 THEN
   NULL
 ELSE
   a.dnhydroseq
 END AS dnhydroseq
,CASE
 WHEN a.dnminorhyd = 0
 THEN
   NULL
 ELSE
   a.dnminorhyd
 END AS dnminorhyd
,a.terminalpathid
,a.fromnode
,a.tonode
,CASE
 WHEN a.hydroseq IN (
   --- Big Tributaries --
    350009839  -- Arkansas
   ,550002171  -- Big Blue
   ,590012528  -- Big Sioux
   ,590004188  -- Bighorn
   ,350003361  -- Black
   ,390006004  -- Black (2)
   ,390000311  -- Canadian
   ,510002921  -- Cedar
   ,590007834  -- Cheyenne
   ,590010733  -- Cheyenne (2)
   ,390001215  -- Cimarron
   ,50004179   -- Clearwater
   ,430000065  -- Cumberland
   ,510002338  -- Des Moines
   ,10002380   -- Feather
   ,720000771  -- Gila
   ,760000231  -- Green
   ,430001637  -- Green
   ,510000257  -- Illinois
   ,510002770  -- Iowa
   ,590008899  -- James
   ,430000838  -- Kanawha
   ,550001526  -- Kansas
   ,430002658  -- Kentucky
   ,720001913  -- Little Colorado
   ,590006912  -- Little Missouri
   ,550008373  -- Loup
   ,590012003  -- Milk
   ,510003597  -- Minnesota
   ,350003335  -- Mississippi from Atchafalaya
   ,550000017  -- Missouri
   ,720001632  -- Muddy
   ,430002416  -- Muskingum
   ,390004971  -- Neosho
   ,590001226  -- Niobrara
   ,550003947  -- North Platte
   ,350003411  -- Ouachita
   ,430000004  -- Ohio
   ,550009800  -- Osage
   ,50003837   -- Owyhee 
   ,680001003  -- Pecos
   ,550000622  -- Platte
   ,590006969  -- Powder
   ,550005927  -- Republican
   ,510001488  -- Rock
   ,50002910   -- Salmon
   ,720001660  -- Salt
   ,760000974  -- San Juan
   ,430002448  -- Scioto
   ,840000351  -- Sheyenne
   ,50001581   -- Snake
   ,550010594  -- Solomon
   ,510003688  -- St. Croix
   ,350005173  -- St. Francis
   ,470000012  -- Tennessee
   ,430001211  -- Wabash
   ,350003903  -- White
   ,590011506  -- White (2)
   ,50004305   -- Willamette
   ,510002581  -- Wisconsin
   ,350005918  -- Yazoo
   ,590001280  -- Yellowstone
   --- Born on the Port Allen Bayou --
   ,350002673
   ,350002676
   ,350002718
   ,350002733
   ,350002775
   ,350002785
   ,350002783
   ,350002835
   ,350002844
   ,350002873
   ,350002878
   ,350002894
   ,350002915
   ,350002946
   ,350002973
   ,350003025
   ,350003055
   ,350003153
   ,350003177
   ,350003182
   ,350003196
   ,350003274
   ,350037594
   ,350045866
   ,350083155
   --- Kaskaskia Old Course --
   ,510000109
   ,510000101
   ,510000102
   ,510000111
   --- Other minor networks receiving big water
   ,510000080
   ,510000089
   ,510000143
   ,550002456
   ,550003310
 )
 THEN
   TRUE
 ELSE
   FALSE
 END AS force_main_line
,ARRAY(SELECT b.fromhydroseq FROM nhdplus.plusflow_np21 b WHERE b.tohydroseq = a.hydroseq) AS ary_upstream_hydroseq
,CASE
 WHEN a.dndraincount = 1
 THEN
   ARRAY[a.dnhydroseq]
 WHEN a.dndraincount = 2
 THEN
   ARRAY[a.dnhydroseq,a.dnminorhyd]
 WHEN a.dndraincount > 2
 THEN
   ARRAY(SELECT c.tohydroseq FROM nhdplus.plusflow_np21 c WHERE c.fromhydroseq = a.hydroseq)
 ELSE
   NULL
 END AS ary_downstream_hydroseq
,CASE
 WHEN a.startflag = 1
 THEN
   CAST('Y' AS VARCHAR(1))
 ELSE
   CAST('N' AS VARCHAR(1))
 END AS headwater
,CASE
 WHEN EXISTS (SELECT 1 FROM nhdplus.plusflow_np21 d WHERE d.fromhydroseq = a.hydroseq AND d.direction = 714 )
 THEN
   CAST('Y' AS VARCHAR(1))
 ELSE
   CAST('N' AS VARCHAR(1))
 END AS coastal_connection
FROM
nhdplus.plusflowlinevaa_np21 a
WHERE
    a.pathlength <> -9999
AND a.fcode <> 56600;

ALTER TABLE nhdplus_navigation30.plusflowlinevaa_nav OWNER TO nhdplus_navigation30;
GRANT ALL ON TABLE nhdplus_navigation30.plusflowlinevaa_nav TO nhdplus_navigation30;
GRANT SELECT ON nhdplus_navigation30.plusflowlinevaa_nav TO public;

CREATE UNIQUE INDEX plusflowlinevaa_nav_01u
ON nhdplus_navigation30.plusflowlinevaa_nav(comid)
TABLESPACE nhdplus_data;

CREATE UNIQUE INDEX plusflowlinevaa_nav_02u
ON nhdplus_navigation30.plusflowlinevaa_nav(hydroseq)
TABLESPACE nhdplus_data;

CREATE INDEX plusflowlinevaa_nav_01i
ON nhdplus_navigation30.plusflowlinevaa_nav(levelpathid)
TABLESPACE nhdplus_data;

CREATE INDEX plusflowlinevaa_nav_02i
ON nhdplus_navigation30.plusflowlinevaa_nav(divergence)
TABLESPACE nhdplus_data;

CREATE INDEX plusflowlinevaa_nav_03i
ON nhdplus_navigation30.plusflowlinevaa_nav(uphydroseq)
TABLESPACE nhdplus_data;

CREATE INDEX plusflowlinevaa_nav_04i
ON nhdplus_navigation30.plusflowlinevaa_nav(dnhydroseq)
TABLESPACE nhdplus_data;

CREATE INDEX plusflowlinevaa_nav_05i
ON nhdplus_navigation30.plusflowlinevaa_nav(dnminorhyd)
TABLESPACE nhdplus_data;

CREATE INDEX plusflowlinevaa_nav_06i
ON nhdplus_navigation30.plusflowlinevaa_nav(pathlength)
TABLESPACE nhdplus_data;

CREATE INDEX plusflowlinevaa_nav_07i
ON nhdplus_navigation30.plusflowlinevaa_nav(pathtimema)
TABLESPACE nhdplus_data;

CREATE INDEX plusflowlinevaa_nav_08i
ON nhdplus_navigation30.plusflowlinevaa_nav(terminalpathid)
TABLESPACE nhdplus_data;

CREATE INDEX plusflowlinevaa_nav_09i
ON nhdplus_navigation30.plusflowlinevaa_nav(force_main_line)
TABLESPACE nhdplus_data;

CREATE INDEX plusflowlinevaa_nav_gn1
ON nhdplus_navigation30.plusflowlinevaa_nav USING GIN(ary_upstream_hydroseq gin__int_ops)
TABLESPACE nhdplus_data;

CREATE INDEX plusflowlinevaa_nav_gn2
ON nhdplus_navigation30.plusflowlinevaa_nav USING GIN(ary_downstream_hydroseq gin__int_ops)
TABLESPACE nhdplus_data;

CREATE INDEX plusflowlinevaa_nav_10i
ON nhdplus_navigation30.plusflowlinevaa_nav(headwater)
TABLESPACE nhdplus_data;

CREATE INDEX plusflowlinevaa_nav_11i
ON nhdplus_navigation30.plusflowlinevaa_nav(coastal_connection)
TABLESPACE nhdplus_data;

--VACUUM FREEZE ANALYZE nhdplus_navigation30.plusflowlinevaa_nav;


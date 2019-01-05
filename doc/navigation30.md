## WATERS Navigation v3.0

#### General

Both Classic logic and NLDI logic use the core NHDPlus table(s) for iteration of the network.  However the act of recursive iteration is fairly expensive with the best performance obtained when the entire dataset is kept entirely in memory.  Furthermore when Classic logic joins the PlusFlowlineVAA to the PlusFlow table that also has a cost.  So for the v3.0 logic the decision was made to implement [a single materialized view](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/375ce01a1725dbc3250926310ee75e57624d6486/src/nhdplus_navigation30/MaterializedViews/PLUSFLOWLINEVAA_NAV.sql#L3) to support all navigation with the following attributes:

1. Remove all unneeded fields for smaller memory footprint.
2. Remove all unnavigable coastlines (about 24,499 records).
3. Embed the logic to determine supplemental extended upstream alternatives as an indexed boolean.
4. Add the Plusflow upstream and downstream hydrosequence references as GIN indexed arrays of integers (no expensive joins) using the [Int Array Extension](https://www.postgresql.org/docs/10/intarray.html).
5. Replace NHDPlus zero values with NULL where appropriate.

The idea here is to have the best of both worlds: both the accuracy of Classic logic and the recursive speed of NLDI logic.  In terms of the accuracy issue, it's worth listing the statistics for the problem.  While at first glance it would seem that it should only affect intersections with a drain count of 4 or more, in fact when an intersection has a drain count of 3 the Down Minor Hydrosequence is always zeroed out rather than "making a choice" among alternatives.  

| Down Drain | Count |
| --- | --- |
| 0 | 8,898  |
| 1 | 2,645,883  |
| 2 | 69,438 |
| 3 | 391 |
| 4 | 1 | 

So to be clear we are discussing a tiny minute percentage of intersections in NHDPlus.  *But* these items also tend to appear along major river systems with the result that sometimes a substantial amount of the upstream watershed can get missed.

#### Upstream with Tributaries

[code reference concise](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/315e42880e658b61e140b54d221fd86b9f47b786/src/nhdplus_navigation30/Functions/NAV_UT_CONCISE.sql#L1)

[code reference extended](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/315e42880e658b61e140b54d221fd86b9f47b786/src/nhdplus_navigation30/Functions/NAV_UT_EXTENDED.sql#L1)

WATERS Navigation v3.0 uses the same query logic as NLDI for "modest" navigation tasks.  Currently the definition of modesty is a start location with an arbolatesum less than 500 having no search limits or a start location with an arbolatesum of less than 200 having a search limit less than 200km or 3 days.  [See the code here](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/7818dff4f250dccfbf6ebd86afbb2827b4406600/src/nhdplus_navigation30/Functions/NAVIGATE.sql#L312-L324).

For navigations beyond these limits I shunt usage to the extended logic.  Extended logic is intended to mitigate [problems in PostgreSQL recursion](/doc/recursion.md) which result in server memory problems for large delineations.  The simplest explanation for extended logic is that we first run an upstream mainline navigation and then run separate upstream with tributaries concise searches for each and every non-mainline branch off that upstream mainline.  This essentially partitions the works into much smaller batches and these smaller batch runs are never able to rejoin the mainline or previous small batch runs.  This makes navigation of the Colorado from the Mexican run smoothly.

But then there is the Mississippi.  It's always about the Mississippi in the end.  Breaking the work into upstream tributaries hits a snag when we have to process the Missouri, the Ohio, the Arkansas, etc.  What we need is for that initial mainline run to also head up these "big" tribs with the definition of big up for some debate.  Here is the [current list](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/375ce01a1725dbc3250926310ee75e57624d6486/src/nhdplus_navigation30/MaterializedViews/PLUSFLOWLINEVAA_NAV.sql#L60-L123).

So then the initial run up the Mississippi will also include the mainlines of the large tributaries.  This is then further complicated in that there exists a number of semi-isolated networks in the bayous of Lousianana which receive minor inflows from the Mississippi.  Going fully upstream from these networks will trigger all the aforementioned problems once the navigation starts chugging up the Mississippi.  These items are [also tagged](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/375ce01a1725dbc3250926310ee75e57624d6486/src/nhdplus_navigation30/MaterializedViews/PLUSFLOWLINEVAA_NAV.sql#L124-L140) so as to trigger mainline navigation of the Mississippi here.  I think I have captured all the most problematic junctions but tuning is always an ongoing process.

#### Upstream Mainline

[code reference](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/315e42880e658b61e140b54d221fd86b9f47b786/src/nhdplus_navigation30/Functions/NAV_UM.sql#L1)

WATERS Navigation V3.0 Upstream Mainline navigation is essentially the same as NLDI logic.

#### Downstream with Divergences

[code reference](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/315e42880e658b61e140b54d221fd86b9f47b786/src/nhdplus_navigation30/Functions/NAV_DD.sql#L1)

NLDI Navigation logic for moving downstream with divergences illustrates very similar problems as with upstream with tributaries logic with a additional twist as regards determining path length.  

#### Downstream Mainline

[code reference](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/315e42880e658b61e140b54d221fd86b9f47b786/src/nhdplus_navigation30/Functions/NAV_DM.sql#L1)

WATERS Navigation V3.0 Downstream Mainline navigation is essentially the same as NLDI logic.

#### Point to Point

[code reference](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/315e42880e658b61e140b54d221fd86b9f47b786/src/nhdplus_navigation30/Functions/NAV_PP.sql#L1)

WATERS Navigation V3.0 Point to Point navigation is a new take on the process that attempts to make the process work in a more reasonable manner to cover more usage scenarios.  The simplest scenario is one where point to point navigation moves downstream along the mainline from start to stop.  Easy enough.  But what if the stop lies on a divergence?  Or what if there are multiple paths possible down multiple divergences?  

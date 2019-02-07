## WATERS Navigation v3.0

#### General

Both Classic logic and NLDI logic use the core NHDPlus table(s) for iteration of the network.  However the act of recursive iteration is fairly expensive with the best performance obtained when the entire dataset is kept entirely in memory.  Furthermore when Classic logic joins the PlusFlowlineVAA to the PlusFlow table that also has a cost.  So for the v3.0 logic the decision was made to implement [a single materialized view](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/375ce01a1725dbc3250926310ee75e57624d6486/src/nhdplus_navigation30/MaterializedViews/PLUSFLOWLINEVAA_NAV.sql#L3) to support all navigation with the following attributes:

1. Remove all unneeded fields for smaller memory footprint.
2. Remove all unnavigable coastlines (about 24,499 records).
3. Embed the logic to determine supplemental extended upstream alternatives as an indexed boolean.
4. Add the Plusflow upstream and downstream hydrosequence references as GIN indexed arrays of integers (no expensive joins) using the [Int Array Extension](https://www.postgresql.org/docs/10/intarray.html).
5. Replace NHDPlus zero values with NULL where appropriate.

The idea here is to have the best of both worlds: both the accuracy of Classic logic and the recursive speed of NLDI logic.  In terms of the accuracy issue, it's worth listing the statistics for the problem.  While at first glance it would seem that it should only affect intersections with a drain count of 4 or more, in fact when an intersection has a drain count of 3 the down minor hydro sequence is always zeroed out rather than "making a choice" among alternatives.  

| Down Drain | Count |
| --- | --- |
| 0 | 8,898  |
| 1 | 2,645,883  |
| 2 | 69,438 |
| 3 | 391 |
| 4 | 1 | 

So to be clear we are discussing a tiny minute percentage of intersections in NHDPlus.  *But* these items also tend to appear along major river systems with the result that sometimes a substantial amount of the upstream watershed can get missed.

#### Upstream Mainline

[code reference](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/315e42880e658b61e140b54d221fd86b9f47b786/src/nhdplus_navigation30/Functions/NAV_UM.sql#L1)

WATERS Navigation V3.0 Upstream Mainline navigation is essentially the same as NLDI logic.

#### Upstream with Tributaries

[code reference modest](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/315e42880e658b61e140b54d221fd86b9f47b786/src/nhdplus_navigation30/Functions/NAV_UT_CONCISE.sql#L1)

[code reference extended](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/315e42880e658b61e140b54d221fd86b9f47b786/src/nhdplus_navigation30/Functions/NAV_UT_EXTENDED.sql#L1)

WATERS Navigation v3.0 uses the same query logic as NLDI for "modest" navigation tasks.  Currently the definition of modesty is a start location with an arbolatesum less than 500 sqkm having no search limits or a start location with an arbolatesum of less than 200 sqkm having a search limit less than 200km or 3 days.  [See the code here](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/7818dff4f250dccfbf6ebd86afbb2827b4406600/src/nhdplus_navigation30/Functions/NAVIGATE.sql#L312-L324).

For navigations beyond these limits I shunt usage to the extended logic.  Extended logic is intended to mitigate [problems in PostgreSQL recursion](/doc/recursion.md) which result in server memory problems for large delineations.  The simplest explanation for extended logic is that we first run an upstream mainline navigation and then run separate upstream with tributaries modest searches for each and every non-mainline branch off that upstream mainline.  This essentially partitions the works into much smaller batches and these smaller batch runs are never able to rejoin the mainline or duplicate the work of earlier small batch runs.  This makes - for example - navigation of the entire Colorado up from the Mexican border run smoothly.

But then there is the Mississippi.  It's always about the Mississippi in the end.  Breaking the work into upstream tributaries hits a snag when we still have to process the Missouri, the Ohio, the Arkansas, etc.  What we need is for that initial mainline run to also head up these "big" tribs - with the definition of big up for some debate.  Here is the [current list](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/da3db54730baed6fe195b951e68ec363c3255e92/src/nhdplus_navigation30/MaterializedViews/PLUSFLOWLINEVAA_NAV.sql#L63-L125).

So then the initial run up the Mississippi will also include the mainlines of the large tributaries.  This is then further complicated in that there exists a number of semi-isolated networks  - particularly in the bayous of Lousianana - which receive minor inflows from the Mississippi.  Going fully upstream from these networks will trigger all the aforementioned problems once the navigation process follows these minor inflows and starts chugging up the Mississippi.  A small example is the old channel of the Mississippi to the west of Kaskaskia, Illinois.  The mainline flowlines of the old channel actually run up local tributaries.  But the channel itself still receives some water from Mississippi proper at the top.  Any attempt to generate the upstream network of the old channel thus must include the full upstream Mississippi proper to avoid problems.  To allow the extended optimization to apply here we need to force the extended mainline processing to also include the full Mississippi.  These items are [also tagged](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/da3db54730baed6fe195b951e68ec363c3255e92/src/nhdplus_navigation30/MaterializedViews/PLUSFLOWLINEVAA_NAV.sql#L126-L157).  I think I have captured all the most problematic junctions but tuning is always an ongoing process.

#### Downstream Mainline

[code reference](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/315e42880e658b61e140b54d221fd86b9f47b786/src/nhdplus_navigation30/Functions/NAV_DM.sql#L1)

WATERS Navigation V3.0 Downstream Mainline navigation is essentially the same as NLDI logic.

#### Downstream with Divergences

[code reference](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/315e42880e658b61e140b54d221fd86b9f47b786/src/nhdplus_navigation30/Functions/NAV_DD.sql#L1)

NLDI Navigation logic for moving downstream with divergences in some cases can illustrate memory problems when downstream recursion duplicates the same channels over and over as paths cross over one another and rejoin the downstream flow.  While this is problematic, more troublesome is the calculation of reasonable network distances on the results.  NLDI navigation does not provide network distance and flowtime by design but certainly uses them internally to determine stop conditions.  But then as NLDI does not calculate by measures there is plenty of wiggle room for eyeballing network distances values.  However as WATERS v3.0 navigation both uses measures and returns network distance we need to generate network distance values are that are reasonable and repeatable.

So the logic overall is the same as the classic downstream with divergences logic - but juiced up though with fast recursion.

* Execute a downstream mainline navigation first.

* Then iterate through each divergence in hydro sequence descending order.

* For each divergence run it's mainline downward adjusting network distance to build from the source flowline on the mainline.

* Then pull a new list of divergences in hydro sequence descending order.

* For each new divergence, run it's mainline downward adjusting network distance to build from the earlier divergence.

* Repeat as needed until all divergences are processed.

Note when doing head-to-head comparisons between Classic and WATERS v3.0 Downstream with Divergences navigation one will find very small variances in the network distance values when the navigation has many divergences within divergences.  This occurs due to the lengthkm value having a lot of precision and the pathlength value only have three places of precision.  WATERS v3.0 builds a new pathlength for the divergence from the top adding together length values of the divergence.  Classic navigation generates an offset which is applied to the existing pathlengths of the divergence.  Its just a precision variance in the way the two methods work.  Ideally one could recalculate the pathlength and pathtime values with higher precision and these differences would then go away.

#### Point to Point

[code reference](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/315e42880e658b61e140b54d221fd86b9f47b786/src/nhdplus_navigation30/Functions/NAV_PP.sql#L1)

WATERS Navigation V3.0 Point to Point navigation is a new take on the process that attempts to make navigation work in a more reasonable manner to cover more usage scenarios.  The simplest scenario is one where point to point navigation moves downstream along the mainline from start to stop.  Easy enough.  But what if the stop lies on a divergence?  Or what if there are multiple paths possible down multiple divergences to reach the stop location?  And as we must report network distances, how do we then return reasonable and repeatable values?

Overall the idea is to closely emulate downstream with divergences logic.

1. Execute a downstream mainline search ceasing navigation at the hydrosequence value of the stop flowline.  Check if the stop flowline occurs within the results and if so, return results.  The general expectation is this will cover the majority of navigations.

2. Otherwise execute a downstream with divergences navigation adding into result set a cost value of 1 for mainline and 100 for divergences.  Check if the stop flowline occurs within the results and if not, then return error code and message.

3. Remove any duplicates created by the downstream with divergences navigation always preserving the lowest cost value.

4. Use the PostgreSQL [pgRouting](https://pgrouting.org/) extension to perform a Dikstra shortest route graph search between the start and stop flowlines.

5. Trim the start and stop flowlines as needed per requested measures

6. Return results.

The simple cost model seems to work just fine as most users would understand the mainline should always be traveled followed by a rough distance calculation among nested tributaries.  However I could imagine a more nuanced costing where mainlines of the divergences themselves have a better cost than divergences of divergences.  I am not sure this needed and always open to feedback.


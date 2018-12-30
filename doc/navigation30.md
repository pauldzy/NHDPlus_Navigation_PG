## WATERS Navigation v3.0

#### General

#### Upstream with Tributaries

[code reference concise](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/315e42880e658b61e140b54d221fd86b9f47b786/src/nhdplus_navigation30/Functions/NAV_UT_CONCISE.sql#L1)

[code reference extended](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/315e42880e658b61e140b54d221fd86b9f47b786/src/nhdplus_navigation30/Functions/NAV_UT_EXTENDED.sql#L1)

WATERS Navigation v3.0 uses the same query as NLDI for "modest" navigation tasks.  Currently the definition of modesty is a start location with an arbolatesum less than 500 and no search limits or a start location with an arbolatesum of less than 200 and a search limit less than 200km or 3 days.  [See the code here](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/7818dff4f250dccfbf6ebd86afbb2827b4406600/src/nhdplus_navigation30/Functions/NAVIGATE.sql#L312-L324).

For navigations beyond these limits I shunt usage to the extended logic.

#### Upstream Mainline

[code reference](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/315e42880e658b61e140b54d221fd86b9f47b786/src/nhdplus_navigation30/Functions/NAV_UM.sql#L1)

#### Downstream with Divergences

[code reference](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/315e42880e658b61e140b54d221fd86b9f47b786/src/nhdplus_navigation30/Functions/NAV_DD.sql#L1)

#### Downstream Mainline

[code reference](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/315e42880e658b61e140b54d221fd86b9f47b786/src/nhdplus_navigation30/Functions/NAV_DM.sql#L1)

#### Point to Point

[code reference](https://github.com/pauldzy/NHDPlus_Navigation_PG/blob/315e42880e658b61e140b54d221fd86b9f47b786/src/nhdplus_navigation30/Functions/NAV_PP.sql#L1)

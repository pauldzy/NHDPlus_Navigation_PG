## NLDI Navigation Logic

#### General

As previously noted, NLDI does provide classic navigation logic via the legacy=true parameter which is documented on the [NLDI OpenAPI documentation](https://cida.usgs.gov/nldi/swagger-ui.html#!/network-controller/getFlowlinesUsingGET_1).  "NLDI navigation logic" in this discussion does not include the legacy code.

NLDI navigation does not make use of the information in the NHDPlus PlusFlow table.  Thus certain flow relationships which cannot be expressed in the NHDPlus PlusFlowlineVAA table are not available to this logic.

#### Upstream Mainline

[code reference](https://github.com/ACWI-SSWD/nldi-services/blob/b7354ed2b6a3be0376c35dae7ff8c4b8626f61d3/src/main/resources/mybatis/navigate.xml#L116-L130)

UM NLDI Navigation uses PostgreSQL recursion to determine the upstream main path by identifying flowlines having a hydrosequence matching the upstream hydrosequence.  While not a problem in itself, this is the opposite logic as used by the UT query.  So a data error could show up in one and not show in the other potentially confusing users.

#### Upstream with Tributaries

[code reference](https://github.com/ACWI-SSWD/nldi-services/blob/b7354ed2b6a3be0376c35dae7ff8c4b8626f61d3/src/main/resources/mybatis/navigate.xml#L140-L155)

UT NLDI Navigation uses PostgreSQL recursion to determine upstream linkage by identifying flowlines having a downstream hydrosequence or downstream minor hydrosequence match.  Thus NLDI does *not* account for situations with more two drains and in cases with more than two drains actually will make only a single upstream match.  

Postgresql recursion as an algorithm is fast and dumb.  As such there is no way within the SQL interface to avoid [recursing the same flowlines multiple times](/doc/recursion.md).  Thus NLDI UT logic is susceptible to memory and processor exhaustion when the upstream watershed is large and the stream path braids back upon themselves repeatedly.

#### Downstream Mainline

[code reference](https://github.com/ACWI-SSWD/nldi-services/blob/b7354ed2b6a3be0376c35dae7ff8c4b8626f61d3/src/main/resources/mybatis/navigate.xml#L68-L81)

DM NLDI Navigation uses PostgreSQL recursion to determine the downstream mainline by identifying flowlines having a hydrosequence value equal to the downstream hydrosequence and with the same terminal path id.

#### Downstream with Divergences

[code reference](https://github.com/ACWI-SSWD/nldi-services/blob/b7354ed2b6a3be0376c35dae7ff8c4b8626f61d3/src/main/resources/mybatis/navigate.xml#L91-L107)

DD NLDI Navigation uses PostgreSQL recursion to determine the downstream with divergences linkage by identifying flowlines having a hydrosequence value equal to the downstream hydrosequence or downstream minor hydrosequence.  There is a short circuit to end navigation if the flowline is the terminal (terminalflag equals one).

DD NLDI Navigation logic does not recalculate path length values from the source flowline for determining distance stop limiters.  This usually does not matter much as the small path length differences in a typical divergence are swallowed up by the results only providing entire flowlines.  However there are some areas whereby results will appear rather odd. 

#### Point to Point

All calls to point to point navigation in NLDI are shunted to the legacy codebase.  So there is no unique point to point NLDI logic.


## NLDI Navigation Logic

#### General

As previously noted, NLDI does provide classic navigation logic via the legacy=true parameter which is documented on the [NLDI OpenAPI documentation](https://cida.usgs.gov/nldi/swagger-ui.html#!/network-controller/getFlowlinesUsingGET_1).  "NLDI navigation logic" in this discussion does not include the legacy code.

NLDI navigation does not make use of the information in the plusflow table.  Thus certain flow relationships which cannot be expressed in the plusflowlinevaa table are not available to this logic.  

#### Upstream with Tributaries

[code reference](https://github.com/ACWI-SSWD/nldi-services/blob/b7354ed2b6a3be0376c35dae7ff8c4b8626f61d3/src/main/resources/mybatis/navigate.xml#L140-L155)

UT NLDI Navigation uses Postgresql recursion to determine upstream linkage by identifying flowlines having a downstream hydrosequence or downstream minor hydrosequence match.  Thus NLDI does *not* account for situations with more two drains and in cases with more than two drains actually will make one upstream match.  

Postgresql recursion as an algorithm is fast and dumb.  As such there is no way within the SQL interface to avoid recursing the same flowlines multiple times.  Thus NLDI UT logic is suseptible to memory and processor problems when the upstream path braids back upon itself.

#### Upstream Mainline

[code reference](https://github.com/ACWI-SSWD/nldi-services/blob/b7354ed2b6a3be0376c35dae7ff8c4b8626f61d3/src/main/resources/mybatis/navigate.xml#L116-L130)

#### Downstream with Divergences

[code reference](https://github.com/ACWI-SSWD/nldi-services/blob/b7354ed2b6a3be0376c35dae7ff8c4b8626f61d3/src/main/resources/mybatis/navigate.xml#L91-L107)

#### Downstream Mainline

[code reference](https://github.com/ACWI-SSWD/nldi-services/blob/b7354ed2b6a3be0376c35dae7ff8c4b8626f61d3/src/main/resources/mybatis/navigate.xml#L68-L81)

#### Point to Point

All calls to point to point navigation in NLDI are shunted to the legacy codebase.  So there is no unique point to point NLDI logic.


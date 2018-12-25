## NLDI Navigation Logic

#### General

NLDI navigation does not make use of the information in the plusflow table.  Thus certain flow relationships which cannot be expressed in the plusflowlinevaa table are not available to this logic.  

NLDI implements a nice caching system to avoid rerunning the navigation for subsequent calls.  This project largely ignores this aspect but having the cache is a helpful performance boost.

#### Upstream with Tributaries

[code reference](https://github.com/ACWI-SSWD/nldi-services/blob/b7354ed2b6a3be0376c35dae7ff8c4b8626f61d3/src/main/resources/mybatis/navigate.xml#L140-L155)

#### Upstream Mainline

[code reference](https://github.com/ACWI-SSWD/nldi-services/blob/b7354ed2b6a3be0376c35dae7ff8c4b8626f61d3/src/main/resources/mybatis/navigate.xml#L116-L130)

#### Downstream with Divergences

[code reference](https://github.com/ACWI-SSWD/nldi-services/blob/b7354ed2b6a3be0376c35dae7ff8c4b8626f61d3/src/main/resources/mybatis/navigate.xml#L91-L107)

#### Downstream Mainline

[code reference](https://github.com/ACWI-SSWD/nldi-services/blob/b7354ed2b6a3be0376c35dae7ff8c4b8626f61d3/src/main/resources/mybatis/navigate.xml#L68-L81)

#### Point to Point

Point to Point NLDI navigation is the same logic as unbounded Downstream Mainline navigation but with a brake to truncate results when the desired downstream flowline is encountered.


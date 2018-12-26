# NHDPlus Stream Network Navigation

The US Environmental Protection Agency's [NHDPlus](https://www.epa.gov/waterdata/nhdplus-national-hydrography-dataset-plus) dataset provides enhanced hydrologic attributes to the medium resolution [National Hydrography Dataset](https://www.usgs.gov/core-science-systems/ngp/national-hydrography/national-hydrography-dataset).  A core component is the network allowing users to trace flow up or downstream for purposes of discovery, analysis or estimation.  Several applications for navigation exist currently - each of which has subtle differences from one another that may be confusing or complicating for users seeking to do their own compariative analysis or write their own navigators.

This project seeks to more straight-forwardly categorize the various products and document their differences making at least the attempt to put forward a solid example logic using the PostgreSQL database.  While a portion of this analysis is based on my own solid experiences over the years with navigation, some is by necessity conjecture.  Please enter an issue if you find anything patently incorrect.  And as always if you need clarification or additional background please consult EPA directly via nhdplus-support@epa.gov.

### Meet the Family

As 2018 comes to a close there are a number of applications and services which allow users to traverse the NHDPlus stream network.  For this project I am proposing a rough division into two main branches: "Classic" and "NLDI".  Navigators for each division differ in how they move around the NHDPlus network and most of the variance users will find derives from these differences.  The navigation v3.0 code provided as part of this project is a hybrid seeking the best of both logics and *perhaps* could spur some discussion on a more standard navigation logic.  Your feedback is most welcome.

##### Classic Navigation

Classic Navigation has existed as a desktop GIS tool now for more than dozen years.  I do not actually know when the logic was first released, sometime in the early 2000s seems a solid guess.  The code was written in .Net as an ArcGIS add-in using [SQL Server Express LocalDB](https://www.microsoft.com/en-us/sql-server/sql-server-editions-express) and released by EPA as the [NHDPlus VAA Navigator Toolbar](https://www.epa.gov/waterdata/nhdplus-tools#vaa).  The current version requires ArcGIS Desktop 10.2.x.

Classic Navigation logic is also a core component of the [NHDPlus BasinDelineator Tool](https://www.epa.gov/waterdata/nhdplus-tools#basin).  The current version of this tool requires ArcGIS Desktop 10.5.1 and the Spatial Analyst extension.

Around 2009 EPA ported the Classic logic into Oracle to drive services under the [Watershed Assessment, Tracking & Environmental Results System (WATERS)](https://www.epa.gov/waterdata/waters-watershed-assessment-tracking-environmental-results-system).  The result was the [Navigation Service](https://www.epa.gov/waterdata/navigation-service) and derivative services including the [Navigation Delineation Service](https://www.epa.gov/waterdata/navigation-delineation-service) and [Upstream Downstream Search Service](https://www.epa.gov/waterdata/upstreamdownstream-search-service).  These public services are now almost a decade old providing various navigation and delineation functionality to a wide variety of users and EPA applications.

Then around 2014 EPA began investigating the potential of utilizing PostgreSQL/PostGIS in the cloud.  As part of this initiative the navigation logic was ported as-is to PL/pgSQL to drive ArcGIS Server hosted geoprocessing services.  While these services were never released officially they existed for many years for evaluation purposes.

While I have never seen the source code for the desktop tools, I contend through experience that the Classic logic remains very similar or identical between the three aforementioned code bases over the past decade.  If you beleive otherwise please drop me a line.  

#### NLDI Navigation

Beginning around 2016 USGS spearheaded the creation of the [Hydro Network Linked Data Index (NLDI)](https://cida.usgs.gov/nldi/about).  As a core component of the system is network navigation, the NLDI team under Dave Blodgett at USGS reimplemented NHDPlus network navigation.  While Classic logic is still available within NLDI when using the legacy=true parameter, the NLDI team sought to leverage PostgreSQL recursion techniques and more powerful cloud servers via a full logic rewrite.

The resulting NLDI services use a PostgreSQL backend with a Java middleware component.  The source code is [hosted on GitHUB](https://github.com/ACWI-SSWD/nldi-services).  Special attention should be paid to the [navigation query SQL](https://github.com/ACWI-SSWD/nldi-services/blob/master/src/main/resources/mybatis/navigate.xml).

The NLDI team made several design decisions that speed up the network calculations over the Classic implementation.  For example NLDI removes all measure evaluation meaning navigation occurs from and to whole flowlines only.  Yet overall the NLDI rewrite is blazingly fast compared head-to-head with Classic navigation - particularly for small to medium sized navigations.  However that same comparison will expose some differences that perhaps need elaboration.  In addition I have found some scaling problems with the NLDI logic that perhaps could be surmounted with larger and larger hardware - but that I and many NHDPlus users do not have.

#### WATERS Navigation v3.0

In the summer of 2018 I finally dove headlong into a prototype that I hoped would take the blazingly fast parts of NLDI but reinject some of the details of Classic navigation and allow better scaling on small hardware.  Thus this third logic is provided part of the project for review and discussion.  Over the past six months I have done a lot of comparisons between the three approaches - sometimes raising thorny questions in the process.  As a result I have been very pleased with performance and beleive the logic is solid and defendable.  So much so that v3.0 is currently driving the geoprocessing services behind [EPA's WATERS GeoViewer](https://epa.maps.arcgis.com/apps/webappviewer/index.html?id=ada349b90c26496ea52aab66a092593b).  But the intention is not just to confuse the situation with another set of logic but rather to document each difference carefully perhaps with an eye towards eventually bringing all three logic families together.

#### Other Navigators

While outside the scope of this project there are some other navigators out there.  One such alternative is the long-forgotten [version 2.0](https://github.com/pauldzy/NHDPlus_Navigation_NDM) from around 2013.  The idea was to entirely rebase NHDPlus Navigation within the [Oracle Network Data Model](https://docs.oracle.com/en/database/oracle/oracle-database/18/topol/network-data-model.html).  While this resulted in a working prototype, the system simply does not scale as results are required to be marshalled in database memory.  So modest navigations work well, but the Mississippi will just run the database out of memory.  

## Discussion Topics

1. [NHDPlus Navigation components](doc/components.md)
2. [Classic Navigation logic](doc/classic.md)
3. [NLDI Navigation logic](doc/nldi.md)
4. [WATERS Navigation v3.0 logic](doc/navigation30.md)
5. [Difference Summary](doc/summary.md)

## Notes

* I have avoided listing any contact information of any of the principle stakeholders in the navigators.  If however you would like me to directly reference you here just drop me a line and I will add you in.

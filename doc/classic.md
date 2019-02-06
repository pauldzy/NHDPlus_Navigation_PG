## Classic Navigation Logic

Classic navigation logic in 2019 may seem rather convoluted and hard to follow.  Yet overall it has met EPA requirements for 15 years or more across a variety of database technology hosted on a variety of modest computing resources.  The ability to request and receive navigation results for the totality of the Mississippi watershed (though admittedly takes quite a while) is a nifty success story.  

#### General

I don't know the design considerations for classic navigation logic but one constraint was that dynamic navigation was limited to a single NHDPlus VPU to conserve computing resources.  Cross-VPU navigation is then precached in static tables and integrated in a post navigation step.  So the logic to span VPU outputs is a complicating factor that the other logic branches simply do not need to address.

Secondly the overall approach is what I often term a "gulp, mark and extract" logic whereby a very large superset of the data is marshaled in a temporary table and then logic committed against that recordset.  Without a doubt the gulping is one of most expensive parts of the process.  It can also make the code hard to follow as recordset selectors are evaluated and adjusted before a final extraction.  If my explanations are lacking please enter an issue to prod me to better explain things.

Navigation in classic logic recurses level paths as it travels for network.  The NLDI rewrite declined to follow this logic instead walking flowline by flowline using the hydroseq primary key.  After consideration I concur that the most straightforward and performant logic is to use hydro sequence pointers avoiding the level path approach.  Thus it is worth emphasizing that fundamentally classic navigation is different from NLDI and WATERS v3.0 navigation in it's usage of level paths.

#### Upstream Mainline

* Test if navigation occurs entirely within a single flowline due to limiter values.  Process such "shorty" navigation via a simple SQL statement clipping the single flowline as needed.

* Load temporary table with all PlusFlowlineVAA records having a hydrosequence value greater than the start flowline from the VPU matching the start flowline.  Limit where appropriate by distance or flowtime.  Exclude coastal flowlines or flowlines having a length of -9999.

* Mark flowlines having the same level path id and terminal path id as the start flowline and a hydrosequence greater than the start flowline.  Limit as appropriate by distance or flowline.  Note the largest upstream hydrosequence and it's level path id value from the set.

* Iterate as many times as needed marking each new upstream level path until headwater, limiter, or VPU connection is met.

* If navigation reached a VPU connection, then continue navigating up the precached cross-VPU results.  Add results into the final output.

* Trim initial start flowline fmeasure value as needed accounting for the start measure. 

#### Upstream with Tributaries

* Test if navigation occurs entirely within a single flowline due to limiter values.  Process such "shorty" navigation via a simple SQL statement clipping the single flowline as needed.

* Load temporary table with all PlusFlowlineVAA records having a hydrosequence value greater than the start flowline from the VPU matching the start flowline.  Limit where appropriate by distance or flowtime.  Exclude coastal flowlines or flowlines having a length of -9999.

* Run upstream via mainline to determine the mainline upstream path.

* Iterate along the mainline loading a secondary temporary table with tributaries that then are used to mark those tributaries in the primary temporary table by their level path id.  Iterate until no other tributaries are found.  

* Check if navigation reached a VPU connection, if so then continue navigating up the precached cross-VPU results.  Add results into the final output.

* Trim initial start flowline fmeasure value as needed accounting for the start measure. 

#### Downstream Mainline

* Test if navigation occurs entirely within a single flowline due to limiter values.  Process such "shorty" navigation via a simple SQL statement clipping the single flowline as needed.

* Load temporary table with all PlusFlowlineVAA records having a hydrosequence value less than the start flowline from the VPU matching the start flowline.  Limit where appropriate by distance or flowtime.  Exclude coastal flowlines or flowlines having a length of -9999.

* Mark flowlines having the same level path id and terminal path id as the start flowline and a hydrosequence greater than the start flowline.  Limit as appropriate by distance or flowline.  Note the smallest downstream hydrosequence and it's level path id value from the set.

* Iterate as many times as needed marking each new upstream level path until headwater, limiter, or VPU connection is met.

* If navigation reached a VPU connection, then continue navigating up the precached cross-VPU results.  Add results into the final output.

* Trim initial start flowline fmeasure value as needed accounting for the start measure. 

#### Downstream with Divergences

Downstream with divergences navigation is different and more complex than other flavors of navigation in that precalculated network distance calculations via NHDPlus path length and path time are not useful when recursing down divergences.  Rather the network distance values needs to be rebuilt as needed for the given divergence in the context of the upstream flow.  This then leads to the need for a simple logic to guide these decisions.  I beleive this logic could be expressed as:

1) Main path rules the navigation and determines the ultimate distance navigated and network distances for flowlines in the main path.  In other words no matter the size or shorter route of any divergences they will never move beyond the extent of the mainline navigation.  So just as with upstream with tributary navigation, when a "short cut" appears the divergence navigation will pause at the reconnect until the mainpath catches up.  

2) Divergences off the mainline are processed in descending hydrosequence order.

3) Each divergence creates it own navigation along it's own mainline running down until it hits a distance limiter or hits the original mainline or a previously processed divergence.  The divergence's network distance is altered to reflect the source location on the mainline.  This altered distance is then reflected down the divergence mainline.

4) After all divergences are processed off the original mainline, then collect a new set of additional divergences from step #3 and repeat until all divergences are processed.

Now is the classic navigation, particularly on the desktop, actually using this logic precisely?  That is a good question for additional research.  There is an arbitrary nature to choosing one divergence over another when we are four or five divergence-within-divergence levels deep into a navigation.  My general thought is to just have a repeatable logic so that different navigators return similar network distance and flow time results.

* Test if navigation occurs entirely within a single flowline due to limiter values.  Process such "shorty" navigation via a simple SQL statement clipping the single flowline as needed.

* Load temporary table with all flowlines in VPU having a hydro sequence value less than or equal to the start flowline from the VPU matching the start flowline.  Limit where appropriate by distance or flowtime.  Exclude coastal flowlines or flowlines having a length of -9999.

* Execute a downstream mainline navigation from the start flowline to determine the downstream mainline path.

* Iterate from the top to the bottom along the mainline path and for each divergence navigate downward adjusting the pathlength/pathtime to match the divergence source location.  Iterate until no more divergences are found.

* If navigation reached a VPU connection, then continue navigating up the precached cross-VPU results.  Add results into the final output.

* Trim initial start flowline fmeasure value as needed accounting for the start measure. 

#### Point to Point

Point to Point navigation via Classic logic has always been a bit of an odd duck.  The NHDPlus desktop navigators have never provided this capability and I have no recollection of where this requirement came from.  Classic point to point logic essentially executes a downstream mainline navigation which halts at the hydrosequence value of the stop flowline.  This may lead to some odd appearing results when the requested stop flowline occurs upon a minor tributary of the mainline.  

* Test if navigation occurs entirely within a single flowline due to limiter values.  Process such "shorty" navigation via a simple SQL statement clipping the single flowline as needed.

* Load temporary table with all PlusFlowlineVAA records having a hydrosequence value less than the start flowline from the VPU matching the start flowline and a hydrosequence more than the stop flowline.  Hydrosequences are sequential between multiple VPUs so if the stop flowline is in a different VPU it all still works.  Exclude coastal flowlines or flowlines having a length of -9999.

* Execute a downstream mainline navigation from the start flowline stopping when the navigation hydrosequence is less than the stop hydrosequence.

* Return any results collected

The problem is that the results may not contain the stop flowline if the stop occurs on a divergence or on a tributary not directly below the start flowline.  A better logic might be to more clearly report the situation such and avoid confusing results.  See the logic in WATERS v3.0 for an alternative approach. 


## Classic Navigation Logic

Classic navigation logic in 2019 may seem rather convoluted and hard to follow.  Yet overall it has met EPA requirements for 15 years or more across a variety of database technology hosted on a variety of modest computing resources.  The ability to request and receive navigation results for the totality of the Mississippi watershed (though admittedly takes quite a while) is a nifty success story.  

#### General

I don't know the design considerations for classic navigation logic but one constraint was that dynamic navigation was limited to a single NHDPlus VPU to conserve computing resources.  Cross-vpu navigation was then precached in static tables and integrated in a post navigation step.  So the logic to span VPU outputs is a complicating factor that the other logic branches simply do not need to address.

Secondly the overall approach is what I often term a "gulp, mark and prune" logic whereby a very large superset of the data is marshalled in a temporary table and then logic committed against that recordset.  It can make the code hard to follow as recordset selectors are adjusted before a final pruning.  If my explanations are lacking please enter an issue to prod me to better explain things.

#### Upstream Mainline

* Test if navigation occurs entirely within a single flowline due to limiter values.  Process such "shorty" navigation via a simple SQL statement clipping the single flowline as needed.

* Load temporary table with all PlusFlowlineVAA records having a hydrosequence value greater than the start flowline from the VPU matching the start flowline.  Limit where appropriate by distance or flowtime.  Exclude coastal flowlines or flowlines having a length of -9999.

* Mark flowlines having the same level path id and terminal path id as the start flowline and a hydrosequence greater than the start flowline.  Limit as appropriate by distance or flowline.  Note the largest hydrosequence and it's level path id values from the set.

* Using the level path id of the largest hydrosequence, iterate again marking flowlines having the same level path as the previous largest hydrosequence and the same terminal path id as the start flowline.  Limit again as appropriate by distance or flowline.  Again note the largest hydrosequence and it's level path id values from the set.

* If headwater, limiter, or VPU connection is met, cease iteration.  Otherwise continue moving upwards by level path id.

* Check if navigation reached a VPU connection, if so then continue navigating up the precached VPU extensions.  Add results into the final output.

* Trim initial start flowline fmeasure value as needed accounting for the start measure. 

#### Upstream with Tributaries

* Test if navigation occurs entirely within a single flowline due to limiter values.  Process such "shorty" navigation via a simple SQL statement clipping the single flowline as needed.

* Load temporary table with all PlusFlowlineVAA records having a hydrosequence value greater than the start flowline from the VPU matching the start flowline.  Limit where appropriate by distance or flowtime.  Exclude coastal flowlines or flowlines having a length of -9999.

#### Downstream Mainline

* Test if navigation occurs entirely within a single flowline due to limiter values.  Process such "shorty" navigation via a simple SQL statement clipping the single flowline as needed.

* Load temporary table with all PlusFlowlineVAA records having a hydrosequence value less than the start flowline from the VPU matching the start flowline.  Limit where appropriate by distance or flowtime.  Exclude coastal flowlines or flowlines having a length of -9999.

#### Downstream with Divergences

* Test if navigation occurs entirely within a single flowline due to limiter values.  Process such "shorty" navigation via a simple SQL statement clipping the single flowline as needed.

* Execute a full downstream mainline navigation from the start flowline

* Load temporary table with all flowlines in VPU having a hydro sequence value less than or equal to the start flowline from the VPU matching the start flowline.  Limit where appropriate by distance or flowtime.  Exclude coastal flowlines or flowlines having a length of -9999.

* Mark flowlines having the same levelpathid and terminalpathid as the start flowline.

#### Point to Point

Point to Point navigation via Classic logic has always been a bit of an odd duck.  The NHDPlus desktop navigators have never provided this capability and I have no recollection of where this requirement came from.  Classic point to point logic essentially executes a downstream mainline navigation which halts at the hydrosequence value of the stop flowline.  This may lead to some odd appearing results when the stop flowline occurs upon a minor tributary of the mainline.  

* Test if navigation occurs entirely within a single flowline due to limiter values.  Process such "shorty" navigation via a simple SQL statement clipping the single flowline as needed.

* Load temporary table with all PlusFlowlineVAA records having a hydrosequence value less than the start flowline from the VPU matching the start flowline and a hydrosequence more than the stop flowline.  Hydrosequences are sequential between multiple VPUs so if the stop flowline is in a different VPU it all still works.  Exclude coastal flowlines or flowlines having a length of -9999.


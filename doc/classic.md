## Classic Navigation Logic

Classic navigation logic in 2019 may seem rather convoluted and hard to follow.  Yet overall it has met EPA requirements for 15 years or more across a variety of database technology hosted on a variety of modest computing resources.  The ability to request and receive navigation results for the totality of the Mississippi watershed (though admittedly takes quite a while) is a nifty success story.  

#### General

I don't know the design considerations for classic navigation logic but one constraint was that navigation overall was limited to a single NHDPlus VPU to conserve computing resources.  So the logic to span VPU outputs is a complicating factor that the other logic branches simply do not need to address.  

Secondly the overall approach is what I often term a "gulp and prune" logic whereby a very large superset of the data is marshalled in a temporary table and then logic committed against that recordset.  It can make the code hard to follow as recordset selectors are adjusted before a final pruning.  If my explanations are lacking please enter an issue to prod me to better explain things.

#### Upstream Mainline

* Test if navigation occurs entirely within a single flowline due to limiter values.  Process such "shorty" navigation via a simple SQL statement clipping the single flowline as needed.

* Load temporary table with all PlusFlowlineVAA records having a hydrosequence value greater than the start flowline from the VPU matching the start flowline.  Limit where appropriate by distance or flowtime.  Exclude coastal flowlines or flowlines having a length of -9999.

* Mark flowlines having the same level path id and terminal path id as the start flowline and a hydrosequence greater than the start flowline.  Limit as appropriate by distance or flowline.  Note the largest hydrosequence and it's level path id values from the set.

* Using the level path id of the largest hydrosequence, iterate again marking flowlines having the same level path as the previous largest hydrosequence and the same terminal path id as the start flowline.  Limit again as appropriate by distance or flowline.  Again note the largest hydrosequence and it's level path id values from the set.

* If headwater or limiter is met, cease iteration.  Otherwise continue moving upwards by level path id.

...

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

* Test if navigation occurs entirely within a single flowline due to limiter values.  Process such "shorty" navigation via a simple SQL statement clipping the single flowline as needed.

* Load temporary table with all PlusFlowlineVAA records having a hydrosequence value less than the start flowline from the VPU matching the start flowline.  Limit where appropriate by distance or flowtime.  Exclude coastal flowlines or flowlines having a length of -9999.

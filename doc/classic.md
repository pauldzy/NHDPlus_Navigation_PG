## Classic Navigation Logic

Classic navigation logic in 2019 may seem rather convoluted and hard to follow.  Yet overall it has met EPA requirements for 15 years or more across a variety of database technology hosted on a variety of modest computing resources.  The ability to request and receive navigation results for the totality of the Mississippi watershed (though admittedly takes quite a while) is a nifty success story.  

#### General

I don't know the design considerations for classic navigation logic but one constraint was that navigation overall was limited to a single NHDPlus VPU to conserve computing resources.  So the logic to span VPU outputs is a complicating factor that the other logic branches simply do not need to address.  

Secondly the overall approach is what I often term a "gulp and prune" logic whereby a very large superset of the data is marshalled in a temporary table and then logic committed against that recordset.  It can make the code hard to follow as recordset selectors are adjusted before a final pruning.  If my explanations are lacking please enter an issue to prod me to better explain things.

#### Upstream Mainline

* Load temporary table with all PlusFlowlineVAA records having a hydrosequence value greater than the start flowline.  Limit where appropriate by distance or flowtime.  Exclude coastal flowlines or flowlines having a length of -9999.

#### Upstream with Tributaries

* Load temporary table with all PlusFlowlineVAA records having a hydrosequence value greater than the start flowline.  Limit where appropriate by distance or flowtime.  Exclude coastal flowlines or flowlines having a length of -9999.

#### Downstream Mainline

* Load temporary table with all PlusFlowlineVAA records having a hydrosequence value less than the start flowline.  Limit where appropriate by distance or flowtime.  Exclude coastal flowlines or flowlines having a length of -9999.

#### Downstream with Divergences

* Execute a full downstream mainline navigation from the start flowline
* Load temporary table with all flowlines in VPU having a hydro sequence value less than or equal to the start flowline.  Limit where appropriate by distance or flowtime.  Exclude coastal flowlines or flowlines having a length of -9999.
* Mark flowlines having the same levelpathid and terminalpathid as the start flowline.

#### Point to Point

* Load temporary table with all PlusFlowlineVAA records having a hydrosequence value less than the start flowline.  Limit where appropriate by distance or flowtime.  Exclude coastal flowlines or flowlines having a length of -9999.

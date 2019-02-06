## Summary

#### Suggested Requirements

Note that not all navigation logics discussed here satisfy all these suggested requirements.  Rather the list is presented as an aid to discussion.

1) Be fast.
2) Be able to navigate the entire Mississippi watershed in a manner reasonable to most users.
3) Utilize the PlusFlow reference table to navigate all connections regardless of drain count.
4) Fully support reach measures and navigation to and from partial flowlines.
5) Return reasonable and repeatable network (path) length and flow time values derived from main stem priorities.  Includes logic downstream with divergences navigation.
6) Return essential flowline attributes (perhaps optionally), in particular GNIS Name values for mapping purposes.

#### Functionality Matrix

| Logic         | Measures | Distance<br/>Limiter | Flowtime<br/>Limiter | Report<br/>Distance | Report<br/>Attributes | Use PlusFlow<br/>Connections |
| ------------- | -------- |----------|----------|----------|------------|--------------|
| Classic Nav   | Yes      | Yes      | No       | Yes      | Yes        | Yes          |
| WATERS v3.0   | Yes      | Yes      | No       | Yes      | Yes        | Yes          |
| NLDI Nav      | No       | Yes      | No       | No       | No         | No           |

#### Topics for further research

1) The utility of the MegaDiv table in navigation is perhaps worth discussion.  It would seem that the PlusFlow table provides all the information in the MegaDiv table with the addition of extremely useful hydro sequence and level path id values.  My general feeling is to skip the MegaDiv table and just fetch needed information from the PlusFlow table.  

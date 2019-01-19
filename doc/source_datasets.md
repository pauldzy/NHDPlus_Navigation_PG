## NHDPlus Navigation Source Datasets

### PlusFlowlineVAA
* Classic
* NLDI
* WATERS v3.0

See [NHDPlus User Guide](https://s3.amazonaws.com/nhdplus/NHDPlusV21/Documentation/NHDPlusV2_User_Guide.pdf) page 52.

Primary NHDPlus network table providing hydro sequence, level path and node connectivity.  One deficiency is as the table only has fields for a single upstream reference and two downstream hydrosequence references, more complicated intersection details are not available without referring to the PlusFlow table. 

### PlusFlow
* Classic
* WATERS v3.0

See [NHDPlus User Guide](https://s3.amazonaws.com/nhdplus/NHDPlusV21/Documentation/NHDPlusV2_User_Guide.pdf) page 54.

The PlusFlow table provides detailed flow direction information regarding the NHDPlus network.  In particular it details network connections with more than one input or two outputs.  Such connections are not available from the PlusFlowlineVAA table alone.

### NHDFlowline
* Classic
* NLDI
* WATERS v3.0

See [NHDPlus User Guide](https://s3.amazonaws.com/nhdplus/NHDPlusV21/Documentation/NHDPlusV2_User_Guide.pdf) page 157.

The NHDFlowline table provides the geometry of the flowline for usage in the payload results.  For Classic and WATERS v3.0 logic certain other attributes are also collected.

### NHDPlusConnect
* Classic

Undocumented in NHDPlus.

The NHDPlusConnect table is an undocumented product listing each and every intra VPU connection in NHDPlus.  The list is not very long.  The table is used to determine when Classic navigation needs to return results spanning multiple VPUs. 

### NHDFCode
* Classic
* WATERS v3.0

See [NHDPlus User Guide](https://s3.amazonaws.com/nhdplus/NHDPlusV21/Documentation/NHDPlusV2_User_Guide.pdf) page 160.

The NHDFCode table is used in Classic and WATERS v3.0 navigation to return the textual description of NHD FCodes in the results payload.  As NLDI navigation provides limited attribute information in its results payload, this information is not required by NLDI logic.

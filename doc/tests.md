#### Shorty Navigation

Input: ComID 22341029, Measure 13.67579, Upstream Mainline or Upstream with Tributaries for 1 km

Output: ComID 22341029, FMeasure 13.67579, TMeasure 49.02648, LengthKM 1 km, Network Distance 1 km

![shortyUT](/doc/shortyUT.png)

Input: ComID 22340547, Measure 35.10735, Downstream Mainline or Downstream with Divergences for 1 km

Output: ComID 22340547, FMeasure 35.10735, TMeasure 35.10735, LengthKM 1 km, Network Distance 1 km

![shortyDM](/doc/shortyDM.png)

![shortyDM_Desktop](/doc/shortyDM_Desktop.png)

Input: ComID 22338859, Measure 73.1257, Point-to-Point to ComID 22338859, Measure 63.90042

Output: ComID 22338859, FMeasure 63.90042, TMeasure 73.1257, LengthKM 0.3683 km, Network Distance 0.3683 km

![shortyPP](/doc/shortyPP.png)

#### Simple Upstream Mainline

Input: ComID 22338561, Measure 25.74585, Upstream Mainline unbounded

Output: ComIDs 22338561, 22338431, 22338423, 22337455, 22337451, 22337449, 22337441, 22337437, 22337431, 22337411, 22337405, 22337383, 22337369, 22337357, 22337529, 22337525, 22337321, 22337317, 22337309, 22337307 ending with FMeasure 0 and TMeasure 100, Network Distance 46.7100 km

![simpleUM](/doc/simpleUM.png)

#### Simple Upstream with Tributaries

Input: ComID 22338811, Measure 65.49847, Upstream with Tributaries unbounded

Output: ComIDs 22338811, 22338753, 22338775, 22338723, 22338727 ending with FMeasure 0 and TMeasure 100, Network Distance 8.1692 km

![simpleUT](/doc/simpleUT.png)

#### Simple Downstream Mainline

Input: ComID 11690150, Measure 79.4848, Downstream Mainline unbounded

Output: ComIDs 11690150, 11690158, 11690164, 11690170, 11690180, 11690174 ending with FMeasure 0 and TMeasure 100, Network Distance 11.3277 km

![simpleDM](/doc/simpleDM.png)

#### Simple Downstream with Divergences

Input: ComID 10960640, Measure 22.83059, Downstream with Divergences unbounded

Output: ComIDs 10960640, 10960646, 10960632, 10960638, 10960628, 10959590, 10960634, 10960630, 10960100, 10960642, 10960644, 10959616, 10960636, 10960038, 10960052, 10960064, 10960090, 10960098, 10960362, ending with FMeasure 0 and TMeasure 100, Network Distance 0.5795 km

![simpleDD](/doc/simpleDD.png)

#### Simple Point to Point

Input: ComID 10529081, Measure 64.49573, Point-to-Point to ComID 8832642, Measure 19.05955

Output: ComIDs 10529081, 10529087, 10529091, 10529093, 10529111, 8832748, 8832624, ending with FMeasure 0 and TMeasure 100, Network Distance 14.0844 km

![shortyPP](/doc/simplePP.png)

#### Upstream with Tributaries including Shortcut

Input: ComID 5894816, Measure 62.93611 upstream for 17 km

Output top of Potomac: ComID 5894782, FMeasure 0, TMeasure 81.16906, Network Distance 17 km

Output top of Potomac inflow to Antietam: ComID 5894756, FMeasure 92.81338, TMeasure 100, Network Distance 16.4047 km

Output top of Antietam: ComID 5891718, FMeasure 35.30358, TMeasure 39.14863, Network Distance 17 km

In this test case there is a distance shortcut through Antietam creek of shorter distance than following the main path of the Potomac river.  NHDPlus navigation via path length requires that the shortcut "pause" at the inflow to the Antietam until the main path "catches up".

![shortcutUT](/doc/shortcutUT.png)

![shortcutUT](/doc/shortcutUT_Desktop.png)

#### Downstream with Divergences including Shortcut

Input: ComID 18124392, Measure 24.4619 downstream for 2.5 km

Output Bottom of West Pascagoula River: ComID 18122576, FMeasure 27.71804, TMeasure 100.00, Network Distance 2.5 km

Output Bottom of shortcut divergence: ComID 18122574, FMeasure 0, TMeasure 100.00, Network Distance 2.3093 km

Output Bottom of other divergence: ComID 18122736, FMeasure 33.38157, TMeasure 100.00, Network Distance 2.5 km

In this test case there is a distance shortcut through the nearby lake of shorter distance than following the main path of the West Pascagoula River.  NHDPlus navigation via path length requires that the shortcut "pause" at the outflow to the West Pascagoula until the main path "catches up".

![shortcutDD](/doc/shortcutDD.png)

![shortcutDD_Desktop](/doc/shortcutDD_Desktop.png)

I am not exactly sure why the desktop tool has that small gap at the top of the lake divergence.

#### Point to Point ending at Divergence

Input: Start ComID 22341029, Measure 42.66844 to Stop ComID 22341031, Measure 36.90974.

WATERS V3.0 Output: ComIDs 22341029, 22341027, 22338669, 22341031 ending at FMeasure 36.90974 for Network Distance 3.2066 km

![divergencePP_v3](/doc/divergencePP_v3.png)

Classic Output: ComIDs 22341029, 22340549, 22340553, 22340561 ending at FMeasure 0.00 for Network Distance 4.4970 km

![divergencePP_cl](/doc/divergencePP_cl.png)

As discussed in the text, Classic navigation logic only finds hydro-sequence-based solutions along the downstream main path.  WATERS v3.0 navigation adds additional routing logic to find a connection to the actual stop location.

Here is a more complex example from ComID 933180286, Measure 17.71519 to ComID 15713777, Measure 54.86753

![divergencePP_v32](/doc/divergencePP_v32.png)

![divergencePP_cl2](/doc/divergencePP_cl2.png)

![](assets/Ropefall_banner_rope.jpg)

# Ropefall is a SketchUp plugin to model ropes, cables, wires. 
The algorithm uses physics simulation of a rope falling to bottom, stopped by obstacles on the way falling down. In this repository you find the source code of it.

[![Ropefall video](https://img.youtube.com/vi/jsuev-g-Xg0/0.jpg)](https://www.youtube.com/watch?v=jsuev-g-Xg0)


Let\'s see how Ropefall works:

![](assets/simple_allthree.jpg)

Animated:

![](assets/animation.gif)

The algorithm simulates a rope that drops downward to the bottom of the
model. The falling rope can be blocked by obstacles in the way. The two
ends of the rope won\'t fall down as they are fixed.

![](assets/Ropefall_params.png)

1. Draw a polyline with the Line tool for the initial shape of the rope, then select it.
2. Click **Extensions → Ropefall → Fall…** (or the Fall button on the Ropefall toolbar).
3. Set the rope length (percent of the polyline or a fixed length), display (line / tube), diameter and,
   for a tube, the number of sides, smoothing and material. Click **Start**. Settings are remembered.
4. Wait until the simulation ends, or keep the rope as it is with Esc, Enter or by picking another tool. The rope group is named with its length
   (e.g. `Rope 3.52m`) and the status bar shows the length.
5. To change a rope later, select it and click **Re-simulate…**: it runs again from the original polyline
   with the new settings and replaces the old rope (one Undo brings the old rope back).

TIP:
- make the simulation faster by hiding parts of the model that do not
block the rope from falling
- use some helper objects to control the shape of the rope
- ropes created before 2.1 cannot be re-simulated (they have no stored data)

## Methods

**Drape** — simulation, the rope drapes over and around objects, its length stays as set.

**Catenary** — instant hanging curve between the first and last point of the selection, ignores objects. TIP: select a straight line and set e.g. 105% for a cable with 5% slack.

Supported SketchUp versions: 2024+

## Build

Run `./build.sh` → `target/ropefall_<version>.rbz`, then install it via Extension Manager → Install Extension. Uninstall any previous Ropefall (1.x) first.

![](assets/demo_allthree.jpg)


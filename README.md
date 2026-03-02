Colorized and table formatted memory tracker for debugging Odin programs. Full credit to Odin (gingerbill) and Karl Zylinski for the original version of the non-formatted version.<br>

This package depends on afmt package.<br>

Create folder "tracker" in the "odin/shared" folder<br>
copy tracker.odin to the "tracker" folder<br>

Add to your project<br>
import "shared:tracker"<br>

Copy to the top of main:<br>
when ODIN_DEBUG {<br>
//tracker.NOPANIC = true // uncomment or override with: -define:nopanic=true<br>
t := tracker.init_tracker()<br>
context.allocator = tracker.tracking_allocator(&t)<br>
defer tracker.print_and_destroy_tracker(&t)<br>
}<br>

Build with:<br>
odin build . -debug

By default, the tracker will panic on bad frees. To override this use:<br>
odin build . -debug -define:nopanic=true<br>

By default, the tracker will use ansi color and attribute formatting. To override this use:<br>
odin build . -debug -define:noansi=true<br>

Output For No Problems
![Alt text](/screenshots/tracker_no_problems.png?raw=true)

Output Detailing Problems Found
![Alt text](/screenshots/tracker_problems.png?raw=true)

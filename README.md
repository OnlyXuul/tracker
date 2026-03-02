# Tracker<br>
Odin tracker for detecting leaks and bad frees of memory allocated using the context.allocator. Output is colorized and table formatted.<br>
<br>
Full credit to Odin (gingerbill) and Karl Zylinski for the original version of the non-formatted version.<br>

**This package depends on [afmt](https://github.com/OnlyXuul/afmt) package.**<br>
## Steps
1. Using the terminal, navigate to odin/shared folder and clone with
   ```bash
   cd /odin/shared
   git clone https://github.com/OnlyXuul/tracker.git
   git clone https://github.com/OnlyXuul/afmt.git
   ```
2. Add to your project<br>
   ```odin
   import "shared:tracker"
   ```
3. Copy to the top of main procedure in your project:<br>
   ```odin
   when ODIN_DEBUG {
   	//tracker.NOPANIC = true // uncomment or override with: -define:nopanic=true
   	t := tracker.init_tracker()
   	context.allocator = tracker.tracking_allocator(&t)
   	defer tracker.print_and_destroy_tracker(&t)
   }
   ```

4. Build with:<br>
   ```
   odin build . -debug
   ```
   By default, the tracker will panic on bad frees. To override this use:<br>
   ```
   odin build . -debug -define:nopanic=true
   ```
   By default, the tracker will use ansi color and attribute formatting. To override this use:<br>
   ```
   odin build . -debug -define:noansi=true
   ```
## Examples
### No Problems<br>
```
odin build . -debug -define:nopanic=true
```

![Alt text](/screenshots/tracker_no_problems.png?raw=true)

### Problems Found<br>
```
odin build . -debug -define:nopanic=true
```

![Alt text](/screenshots/tracker_problems.png?raw=true)

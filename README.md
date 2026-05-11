# Tracker<br>
Odin tracker for detecting leaks and bad frees of memory allocated using the context.allocator. Output is colorized and table formatted.<br>
<br>
Full credit to Odin (gingerbill) and Karl Zylinski for the original version of the non-formatted version.<br>

**This package depends on [afmt](https://github.com/OnlyXuul/afmt) package.**<br>

**Requires Odin version 2026-03 or later. See [moving-towards-a-new-core-os](https://odin-lang.org/news/moving-towards-a-new-core-os/)**<br>

Check out [Ginger Bill’s Memory Allocation Strategy series](https://www.gingerbill.org/series/memory-allocation-strategies/) for tips on memory management.

## Steps
1. Using the terminal, navigate to odin/shared folder and clone with
   ```bash
   cd $(odin root)shared
   git clone https://github.com/OnlyXuul/tracker.git
   git clone https://github.com/OnlyXuul/afmt.git
   ```
2. Add to your project<br>
   ```odin
   import "shared:tracker"
   ```
3. Copy into your project:<br>
   ```odin
   // Non-Global Tracker - Most used - Benefits from main() as the originating scope for everything else after
   // Copy-Paste this to top of main in your project
	when ODIN_DEBUG {
		//tracker.NOPANIC = true // uncomment or override with: -define:nopanic=true
		t := tracker.init()
		context.allocator = t.allocator
		defer tracker.print_and_destroy(&t)
   }

   // or ...

   // Global Tracker - 3 parts - Useful when procedures do not originate from the same scope (i.e. no main procedure)
   // Part 1 - Copy-Paste this to beginning of init() procedure like in wasm
   when ODIN_DEBUG {
		//tracker.NOPANIC = true // uncomment or override with: -define:nopanic=true
		tracker.init_global()
		context.allocator = tracker.global.allocator
	}
   // Part 2 - Copy and paste this to the beginning of every procedure you wish tracker to collect data for
   when ODIN_DEBUG {
		context.allocator = tracker.global.allocator
	}
   // Part 3 - Copy and past this to beginning of final procedure like shutdown() in wasm
   when ODIN_DEBUG {
		context.allocator = tracker.global.allocator
		defer tracker.print_and_destroy(&tracker.global)
	}
   ```
4. Build your project with:<br>
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
## Run example.odin
   ```bash
   cd $(odin root)shared/tracker/example
   odin run . -debug -define:nopanic=true
   ```
## Example Output
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

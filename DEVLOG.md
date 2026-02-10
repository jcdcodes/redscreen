Dev log
=======

I started by wondering what it would take to make [OverlayApp](https://github.com/jcdcodes/overlayapp) do something like the "darkroom mode" that I remember from a couple decades ago on a Linux machine I had, and from a decade or two ago on an Apple machine that I ran [f.lux](https://justgetflux.com/) on.  Note that f.lux is still available on the Mac and is way more polished than the present project; though the present project is really small and has no ability to phone home over the internet.

The prompts I gave to Claude Code
---------------------------------

1. "I'd like to understand options for a macOS utility that makes everything onscreen be red on black.  that way I can be less distracted by colors and bright lights as I work, and I can use it at night without illuminating my whole workspace.  there was a thing called "flux" that did this many years ago on the Mac, which I'm attempting to understand how to reproduce."

    * It responded with a few options, including a combination of Night Shift and custom ColorSync profiles and Smart Invert.  And it said that one can write a simple Swift utility using `CGSetDisplayTransferByFormula` and a bunch of other macOS API classes that I don't have any working familiarity with.  It also reminded me that f.lux is the easiest option.

2. "I guess I'd use f.lux but it's not open source so I can't examine what it's doing.  so let's try to make the simple swift utility you describe."

    * It made me a single file called `redscreen.swift` that I ran from the command line.  It almost worked.

3. "it flashes the screen ever so briefly, but that's about it; the screen stays normally colored.  I turned night shift on and off and the response is the same."

    * It did a web search (I couldn't see the search terms it used) and found a thing called [RedScreen](https://github.com/interealtime/RedScreen) on GitHub (which I wish I'd known about 13 years ago!!) and then it read its Objective-C code to see what approach that project took.  It tweaked `redscreen.swift` which then worked perfectly on my machine.  But it was reddening the white (background) pixels instead of inverting everything to white text on black background and then reddening the text.

4. "let's have it invert the screen also"

    * The result was that it stopped working at all.

5. "now it's no-opping"

    * The model gave a reason (an inbuilt `max > min` assertion) and switched from `CGSetDisplayTransferByFormula` to `CGSetDisplayTransferByTable`.  This worked perfectly.
	
	* Note: if I were doing this by hand, I'd likely have spent at least 15 minutes getting frustrated and failing to perceive the difference between `CGDisplaySetTransferByTable` and `CGSetDisplayTransferByTable`.
   
5. "let's convert this from a command line utility to a menubar utility, an app that lives in the menubar and can be adjusted/quit from its menu bar icon"

    * That worked great also, except that I still had to run it from the command line, and the brightness slider was stacked on top of the computer's already perfectly suitable native brightness controls, so everything was way too dark.

6. "Can I have this as a double clickable .app, or does that require a whole apple signing ceremony?"

    * It said no, and wrote me `build.sh`, which you see nearby.

7. "get rid of the brightness slider.  user can set their own brightness with inbuilt controls."

    * It did so, but left a variable in the code called `brightness` hardcoded to 1.0 that was only ever used to multiply other numbers.

8. "clean up: remove the `brightness` variable because it's just a hardcoded 1.0 that only ever gets multiplied"

    * It did so.


Mostly manual documentation
---------------------------

Then I took a break and wrote this devlog up and got the whole thing checked into git on my machine, and then to github.  I manually fixed the AI-flavored `README.md` file; hopefully you find that it reads better than the original, which I've kept around as `README_BY_CLAUDE.md`.  This manual writeup took probably thirty minutes; the whole "build me a darkroom mode thing" experience was mostly done after about ten minutes.

Causing code to exist is really not the hardest part anymore.


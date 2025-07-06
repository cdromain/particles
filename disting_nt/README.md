# particles  
*A nature-inspired generative algorithm for the **disting NT** ✨*  

![version](https://img.shields.io/badge/version-v0.1-blue) ![status](https://img.shields.io/badge/status-beta-orange)  

> *"The world is nothing but a ceaseless flux of events. A continuous dance of particles. We are, ourselves, a part of this dance."*
— Carlo Rovelli

## What it is
`particles` is a Lua generative algorithm that runs on the **disting NT** (and soon norns).  

On screen, different-sized particles fall under gravity while wind pushes them sideways, drifting through dust, colliding and creating an organic stream of physically-driven CV & triggers events :

| Event | CV | TRIG |
|-------|----|------|
| Particle hits ground | `pitch CV` | `particle Trig` |
| Two particles collide | `random CV` | `collision Trig` |

## Installation

1. Copy `particles.lua` to the `programs/lua` folder on your disting NT’s SD card.  
2. Load the Lua Script algorithm, then select **particles**.  
3. **Firmware:** Tested on disting NT fw 1.09.

## Default output assignment

| Output | Signal |
|--------|--------|
| **3** | Pitch CV (particle→ground) |
| **4** | Trig (particle→ground) |
| **5** | Random CV (particles collision) |
| **6** | Trig (particles collision) |

*(Internally the script exposes 4 outputs; on disting NT these map to outs 3-6.)*

## Live parameters

All parameters are visible in the disting NT’s top menu.

| # | Name | Range / Steps | Notes |
|---|------|---------------|-------|
| 1 | **Root Note** | 0-11 | 0 = C, 1 = C♯/D♭ … 11 = B |
| 2 | **Octave** | 0-8 | Centre your melody |
| 3 | **Scale** | 1-9 | minor, major, dorian, phrygian, lydian, mixolydian, locrian, harmonic minor, melodic minor |
| 4 | **Global Fall Speed** | 0.1-25 × | Master speed multiplier |
| 5 | **Gravity** | 0.1-5 × | Base speed derived from particle size |
| 6 | **Max Particles** | 1-12 | More particles = busier soundscape
| 7 | **Wind** | 0-1.0 | L/R sway strength |
| 8 | **Verbose** | 0/1 | Show CV & trig values on screen |

## Quick-start patch

Use the pitch CV & particle trig to play a plucky voice  (e.g. Rings), the collision trig to trigger some noise (Plonk, sample...), and the random CV to spice up your patch. Add some delay and reverb seasoning to taste and sit back.

## Credits & inspiration

* Freely inspired by Ambalek’s beautiful [**fall**](https://github.com/ambalek/fall) script for norns 🍃  
* Written by **Romain Faure** (2025) with support from [thorinside](https://github.com/thorinside) and the disting community.
* Os for opening up the disting NT to Lua scripting, making it all possible 🙌🏼

## Contributing

Feedback, bug reports, feature ideas and pull requests welcome.  
Please use a feature branch and follow conventional commit messages (`feat: …`, `fix: …`).

## Licence

MIT – see [LICENCE](./LICENCE) for details. Use, fork, remix, enjoy!  
If you release a derivative work, please keep a nod to *particles* and the original *fall*.

---

*Version 0.1 (Beta) – July 2025*
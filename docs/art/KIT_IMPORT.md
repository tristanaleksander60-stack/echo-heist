# Kit import: from FBX files to `assets/Kit.rbxm` (spike S2)

_For the owner. About 45 minutes the first time, 10 minutes after that. Updated 2026-11-12 for the launch kit v1, pass 2 (review fixes)._

**Goal.** Claude builds the art in Blender and writes FBX files to `assets/fbx/`. Roblox Studio must import them once and save them as one file, `assets/Kit.rbxm`. Rojo then puts that file into `ServerStorage/Kit`. The game only **clones** these pieces. It never creates meshes itself.

**Spike S2 passes when** the built place has every piece with the right size and the right collision (MASTERPLAN §8.11).

**What changed since v0.** The bank kit v0 (6 files) became the launch kit: walls, doors, windows, the storefront, floors, counters, shelves, lamps, plates, switches, laser posts, hiding spots, a safe, the van, loot, three hero props (the golden-pass vault door, the cash register with the diamond pedestal, the Giant Present), the Christmas dressing layer and Gus. `Bank_Wall_*` is now `Wall_*` (one kit for every location) and `VaultDoor_Greybox` is now `VaultDoor`. If you imported v0 already, delete it and import everything again.

**Pass 2 (review fixes, 2026-11-12).** New: the loot the levels use (`Present`, `Candy`, `Toy`, `Teddy`), `Shutter_8x10` (the LOCKDOWN leaf), `BankFront_24x12`, `Shelf_Gondola_8x2` (Clone Party aisles), `Hide_CoatStand`, `Hide_DepositStack`. Remade: `Hide_Plant` (a planter niche that shows the plate), `Hide_CoatRack` (double rack over a plate), `Hide_Crate` (2.5 deep), `Xmas_SnowPile`, tintable `Ornament_Bauble` / `_Bell` / `_Star`. The atlas changed (lighter wood, readable from above), so **every** FBX changed: import them all. The prepare script now finds pieces safely (the v1 script could never print KIT OK) and wall modules are placed **centred on their grid line** (below).

**Automated path (Nov 12): no Studio needed.** Claude uploads every FBX with Open Cloud and the server loads the kit at boot (`KitService`). See [Automated path](#automated-path-no-studio-open-cloud-upload--kitservice) below. The Studio steps that follow are the manual path; they still work (KitService uses a Rojo-mapped `ServerStorage/Kit` when one exists) but S2 no longer waits on them.

The table below shows what Studio must show after the import (generated from `assets/fbx/kit_manifest.json` by `python3 tools/blender/kit_docs.py`). Studio uses Y for up, so sizes are X x Y x Z.

<!-- kit-table:start -->
| Model (FBX) | MeshPart | Size in Studio (X x Y x Z) | Tris | Collision | Material | CanCollide | CastShadow | Layer |
|---|---|---|---|---|---|---|---|---|
| BankFront_24x12.fbx | BankFront_24x12 | 24 x 13.9 x 2.94 | 2244 | PreciseConvexDecomposition | SmoothPlastic | on | on | base |
| BankersLamp.fbx | BankersLamp | 1.32 x 1.44 x 0.86 | 328 | Box | SmoothPlastic | off | off | base |
| Candy.fbx | Candy | 2.64 x 1.1 x 1.1 | 336 | Box | SmoothPlastic | on | off | base |
| Car_Parked.fbx | Car_Parked | 4.1 x 3.743 x 9.44 | 476 | Box | SmoothPlastic | off | off | base |
| Car_Parked.fbx | Car_Parked_Paint | 4.2 x 2.6 x 9 | 88 | Box | SmoothPlastic | off | off | base |
| CashBag.fbx | CashBag | 1.9 x 2.02 x 1.97 | 600 | Box | SmoothPlastic | on | off | base |
| CashRegister.fbx | CashRegister | 4.14 x 3.95 x 3.2 | 1032 | Box | SmoothPlastic | off | on | base |
| CashRegister.fbx | CashRegister_Drawer | 2.97 x 0.67 x 2.77 | 488 | Box | SmoothPlastic | off | off | base |
| Ceiling_8x8.fbx | Ceiling_8x8 | 8 x 0.55 x 8 | 168 | Box | SmoothPlastic | off | off | base |
| Clock_6.fbx | Clock_6 | 6.7 x 6.7 x 0.86 | 400 | Box | SmoothPlastic | off | off | base |
| Column_2x12.fbx | Column_2x12 | 2 x 12 x 2 | 600 | Box | SmoothPlastic | off | on | base |
| Cornice_8.fbx | Cornice_8 | 8 x 1.98 x 2.8 | 152 | Box | SmoothPlastic | off | off | base |
| Counter_4x4.fbx | Counter_4x4 | 4.3 x 3.5 x 4.3 | 208 | Box | SmoothPlastic | on | on | base |
| Counter_8x2.fbx | Counter_8x2 | 8.3 x 3.5 x 2.3 | 244 | Box | SmoothPlastic | on | on | base |
| Counter_8x4.fbx | Counter_8x4 | 8.3 x 3.5 x 4.3 | 316 | Box | SmoothPlastic | on | on | base |
| Decor_Bank.fbx | Decor_Bench_6 | 6 x 2.05 x 1.8 | 160 | Box | SmoothPlastic | off | on | base |
| Decor_Bank.fbx | Decor_BrassRail_8 | 7.96 x 3.03 x 0.965 | 768 | Box | SmoothPlastic | off | on | base |
| Decor_Bank.fbx | Decor_DepositWall_8 | 8.2 x 7 x 0.55 | 1220 | Box | SmoothPlastic | off | off | base |
| Decor_Bank.fbx | Decor_Palm | 3.235 x 6.093 x 3.235 | 504 | Box | SmoothPlastic | off | on | base |
| Decor_Bank.fbx | Decor_QueueRope_8 | 8.1 x 3.22 x 0.9 | 600 | Box | SmoothPlastic | off | on | base |
| Decor_Office.fbx | Decor_Boxes | 3.6 x 4.42 x 2.45 | 340 | Box | SmoothPlastic | off | on | base |
| Decor_Office.fbx | Decor_CoatHooks_4 | 4 x 3.4 x 0.75 | 288 | Box | SmoothPlastic | off | off | base |
| Decor_Office.fbx | Decor_Corkboard_4 | 4 x 3 x 0.24 | 272 | Box | SmoothPlastic | off | off | base |
| Decor_Office.fbx | Decor_Desk_6 | 6 x 4.95 x 3 | 488 | Box | SmoothPlastic | off | on | base |
| Decor_Shop.fbx | Decor_CandyCounter_6 | 6.3 x 4.3 x 2.7 | 472 | Box | SmoothPlastic | off | on | base |
| Decor_Shop.fbx | Decor_CardString_8 | 8.16 x 1.529 x 0.14 | 264 | Box | SmoothPlastic | off | off | xmas |
| Decor_Shop.fbx | Decor_CatBed | 2.7 x 1.01 x 2.632 | 404 | Box | SmoothPlastic | off | on | base |
| Decor_Shop.fbx | Decor_Fridge_4 | 4.4 x 8 x 2.95 | 988 | Box | SmoothPlastic | off | on | base |
| Decor_Shop.fbx | Decor_Fridge_4_Glass | 3.74 x 6.05 x 0.04 | 12 | Box | Glass (T 0.6) | off | off | base |
| Decor_Shop.fbx | Decor_Fridge_4_Light | 3.8 x 0.2 x 0.2 | 12 | Box | Neon | off | off | base |
| Decor_Shop.fbx | Decor_MagRack_3 | 3.44 x 4.6 x 1.6 | 372 | Box | SmoothPlastic | off | on | base |
| Decor_Shop.fbx | Decor_MopBucket | 1.7 x 5.999 x 2.298 | 192 | Box | SmoothPlastic | off | on | base |
| Decor_Shop.fbx | Decor_Poster_A | 2.4 x 3.2 x 0.11 | 100 | Box | SmoothPlastic | off | off | base |
| Decor_Shop.fbx | Decor_Poster_B | 2.4 x 3.2 x 0.11 | 72 | Box | SmoothPlastic | off | off | base |
| Decor_Shop.fbx | Decor_StockShelf_8 | 8.2 x 7.5 x 2.1 | 1324 | Box | SmoothPlastic | off | on | base |
| Decor_Shop.fbx | Decor_WallClock | 2 x 2 x 0.35 | 328 | Box | SmoothPlastic | off | off | base |
| Decor_Theme.fbx | Decor_Bakery_Cakes | 2.8 x 4.26 x 2.73 | 1084 | Box | SmoothPlastic | off | on | base |
| Decor_Theme.fbx | Decor_Deli_Case | 6 x 6.35 x 2.58 | 572 | Box | SmoothPlastic | off | on | base |
| Decor_Theme.fbx | Decor_Grocer_Fruit | 5 x 3.26 x 3.12 | 1524 | Box | SmoothPlastic | off | on | base |
| Decor_Theme.fbx | Decor_Jeweller_Case | 5.05 x 5.3 x 2.35 | 1128 | Box | SmoothPlastic | off | on | base |
| Decor_Theme.fbx | Decor_Pharmacy_Counter | 6.3 x 7 x 2.75 | 524 | Box | SmoothPlastic | off | on | base |
| Decor_Theme.fbx | Decor_Repair_Bench | 6 x 7 x 2.6 | 552 | Box | SmoothPlastic | off | on | base |
| Decor_Toy.fbx | Decor_CandyCane_Giant | 3.256 x 9.191 x 1.8 | 696 | Box | SmoothPlastic | off | on | xmas |
| Decor_Toy.fbx | Decor_GiftWrap_6 | 6 x 4.544 x 3 | 444 | Box | SmoothPlastic | off | on | base |
| Decor_Toy.fbx | Decor_RockingHorse | 4.03 x 3.587 x 1.3 | 436 | Box | SmoothPlastic | off | on | base |
| Decor_Toy.fbx | Decor_ToyShelf_8 | 8.2 x 7.5 x 2.1 | 1648 | Box | SmoothPlastic | off | on | base |
| Decor_Toy.fbx | Decor_TrainLoop_6 | 6 x 2.43 x 3.2 | 452 | Box | SmoothPlastic | off | on | base |
| Decor_Trim.fbx | Ceiling_8x8_Tin | 8 x 0.55 x 8 | 168 | Box | SmoothPlastic | off | off | base |
| Decor_Trim.fbx | Decor_Frieze_8 | 8 x 0.85 x 0.2 | 108 | Box | SmoothPlastic | off | off | base |
| Diamond.fbx | Diamond | 2 x 1.75 x 2 | 94 | Box | SmoothPlastic | off | off | base |
| Facade_8x10.fbx | Facade_8x10 | 8 x 9.15 x 1.4 | 360 | Box | SmoothPlastic | off | off | base |
| Facade_8x10.fbx | Facade_8x10_Body | 8 x 10 x 1 | 48 | Box | SmoothPlastic | off | off | base |
| Facade_Curtain.fbx | Facade_Curtain | 3.4 x 5.26 x 0.2 | 132 | Box | SmoothPlastic | off | off | base |
| FireEscape_8x10.fbx | FireEscape_8x10 | 7.4 x 11.473 x 3 | 296 | Box | SmoothPlastic | off | off | base |
| Floor_8x8.fbx | Floor_8x8 | 8 x 0.5 x 8 | 144 | Box | SmoothPlastic | on | on | base |
| GarageDoor_16x12.fbx | GarageDoor_16x12 | 16 x 12 x 2.36 | 364 | Box | SmoothPlastic | off | on | base |
| GiantPresent.fbx | GiantPresent | 7.2 x 6.794 x 7.2 | 1380 | Box | SmoothPlastic | on | on | base |
| GoldBar.fbx | GoldBar | 2 x 0.6 x 1 | 52 | Box | SmoothPlastic | on | off | base |
| GoldStack.fbx | GoldStack | 2.04 x 1.8 x 3.1 | 312 | Box | SmoothPlastic | on | on | base |
| Gus.fbx | Gus_Cap | 2.04 x 0.799 x 2.359 | 184 | Box | SmoothPlastic | off | on | base |
| Gus.fbx | Gus_Flashlight | 0.98 x 0.98 x 2.29 | 336 | Box | SmoothPlastic | off | on | base |
| Gus.fbx | Gus_FlashlightLens | 0.8 x 0.8 x 0.05 | 48 | Box | Neon | off | off | base |
| Gus.fbx | Gus_Head | 2.08 x 1.6 x 1.946 | 560 | Box | SmoothPlastic | off | on | base |
| Gus.fbx | Gus_LeftFoot | 0.84 x 0.65 x 1.37 | 80 | Box | SmoothPlastic | off | on | base |
| Gus.fbx | Gus_LeftHand | 0.638 x 0.704 x 0.64 | 116 | Box | SmoothPlastic | off | on | base |
| Gus.fbx | Gus_LeftLowerArm | 0.712 x 0.966 x 0.628 | 120 | Box | SmoothPlastic | off | on | base |
| Gus.fbx | Gus_LeftLowerLeg | 0.72 x 0.87 x 0.685 | 80 | Box | SmoothPlastic | off | on | base |
| Gus.fbx | Gus_LeftUpperArm | 0.84 x 1.348 x 0.799 | 180 | Box | SmoothPlastic | off | on | base |
| Gus.fbx | Gus_LeftUpperLeg | 0.84 x 0.94 x 0.799 | 80 | Box | SmoothPlastic | off | on | base |
| Gus.fbx | Gus_LowerTorso | 2.499 x 0.96 x 1.916 | 424 | Box | SmoothPlastic | off | on | base |
| Gus.fbx | Gus_RightFoot | 0.84 x 0.65 x 1.37 | 80 | Box | SmoothPlastic | off | on | base |
| Gus.fbx | Gus_RightHand | 0.638 x 0.704 x 0.64 | 116 | Box | SmoothPlastic | off | on | base |
| Gus.fbx | Gus_RightLowerArm | 0.712 x 0.966 x 0.628 | 120 | Box | SmoothPlastic | off | on | base |
| Gus.fbx | Gus_RightLowerLeg | 0.72 x 0.87 x 0.685 | 80 | Box | SmoothPlastic | off | on | base |
| Gus.fbx | Gus_RightUpperArm | 0.84 x 1.348 x 0.799 | 180 | Box | SmoothPlastic | off | on | base |
| Gus.fbx | Gus_RightUpperLeg | 0.84 x 0.94 x 0.799 | 80 | Box | SmoothPlastic | off | on | base |
| Gus.fbx | Gus_UpperTorso | 2.72 x 2.07 x 2.435 | 624 | Box | SmoothPlastic | off | on | base |
| Gus_DonutBox.fbx | Gus_DonutBox | 2.6 x 2.385 x 2.45 | 596 | Box | SmoothPlastic | off | on | base |
| Gus_SantaHat.fbx | Gus_SantaHat | 2.24 x 1.781 x 2.736 | 360 | Box | SmoothPlastic | off | on | xmas |
| Hide_CoatRack.fbx | Hide_CoatRack | 6 x 6.85 x 4.8 | 544 | Box | SmoothPlastic | off | on | base |
| Hide_CoatStand.fbx | Hide_CoatStand | 4.747 x 7.13 x 4.67 | 572 | Box | SmoothPlastic | off | on | base |
| Hide_Crate.fbx | Hide_Crate | 4.443 x 5.85 x 2.74 | 552 | Box | SmoothPlastic | off | on | base |
| Hide_Curtain.fbx | Hide_Curtain | 6.38 x 10.78 x 1.84 | 468 | Box | SmoothPlastic | off | on | base |
| Hide_DepositStack.fbx | Hide_DepositStack | 6.24 x 7 x 6.355 | 696 | Box | SmoothPlastic | off | on | base |
| Hide_Plant.fbx | Hide_Plant | 6.293 x 6.174 x 5.969 | 568 | Box | SmoothPlastic | off | on | base |
| Hoardsworth.fbx | Hoardsworth_Hat | 1.6 x 1.42 x 1.44 | 364 | Box | SmoothPlastic | off | on | base |
| Hoardsworth.fbx | Hoardsworth_Head | 1.269 x 1.44 x 1.195 | 756 | Box | SmoothPlastic | off | on | base |
| Hoardsworth.fbx | Hoardsworth_LeftFoot | 0.42 x 0.62 x 1.25 | 140 | Box | SmoothPlastic | off | on | base |
| Hoardsworth.fbx | Hoardsworth_LeftHand | 0.418 x 0.525 x 0.42 | 116 | Box | SmoothPlastic | off | on | base |
| Hoardsworth.fbx | Hoardsworth_LeftLowerArm | 0.518 x 1.044 x 0.476 | 160 | Box | SmoothPlastic | off | on | base |
| Hoardsworth.fbx | Hoardsworth_LeftLowerLeg | 0.36 x 1.62 x 0.342 | 80 | Box | SmoothPlastic | off | on | base |
| Hoardsworth.fbx | Hoardsworth_LeftUpperArm | 0.632 x 1.379 x 0.571 | 180 | Box | SmoothPlastic | off | on | base |
| Hoardsworth.fbx | Hoardsworth_LeftUpperLeg | 0.44 x 1.62 x 0.418 | 80 | Box | SmoothPlastic | off | on | base |
| Hoardsworth.fbx | Hoardsworth_LowerTorso | 1.44 x 1.98 x 1.256 | 308 | Box | SmoothPlastic | off | on | base |
| Hoardsworth.fbx | Hoardsworth_Monocle | 0.475 x 0.721 x 0.349 | 192 | Box | SmoothPlastic | off | on | base |
| Hoardsworth.fbx | Hoardsworth_RightFoot | 0.42 x 0.62 x 1.25 | 140 | Box | SmoothPlastic | off | on | base |
| Hoardsworth.fbx | Hoardsworth_RightHand | 0.418 x 0.525 x 0.42 | 116 | Box | SmoothPlastic | off | on | base |
| Hoardsworth.fbx | Hoardsworth_RightLowerArm | 0.518 x 1.044 x 0.476 | 160 | Box | SmoothPlastic | off | on | base |
| Hoardsworth.fbx | Hoardsworth_RightLowerLeg | 0.36 x 1.62 x 0.342 | 80 | Box | SmoothPlastic | off | on | base |
| Hoardsworth.fbx | Hoardsworth_RightUpperArm | 0.632 x 1.379 x 0.571 | 180 | Box | SmoothPlastic | off | on | base |
| Hoardsworth.fbx | Hoardsworth_RightUpperLeg | 0.44 x 1.62 x 0.418 | 80 | Box | SmoothPlastic | off | on | base |
| Hoardsworth.fbx | Hoardsworth_UpperTorso | 1.88 x 2.7 x 1.379 | 552 | Box | SmoothPlastic | off | on | base |
| Intro_House_A.fbx | Intro_House_A | 13.6 x 17.79 x 12.8 | 984 | Box | SmoothPlastic | off | on | base |
| Intro_House_A.fbx | Intro_House_A_Windows | 12.16 x 7.3 x 6.48 | 108 | Box | Neon | off | off | base |
| Intro_House_B.fbx | Intro_House_B | 16.6 x 17.05 x 12.8 | 984 | Box | SmoothPlastic | off | on | base |
| Intro_House_B.fbx | Intro_House_B_Windows | 15.16 x 5.3 x 6.48 | 108 | Box | Neon | off | off | base |
| Intro_Letter.fbx | Intro_Letter | 2.4 x 1.6 x 0.2 | 160 | Box | SmoothPlastic | off | off | base |
| Intro_Lever.fbx | Intro_Lever | 2 x 3.059 x 1.4 | 200 | Box | SmoothPlastic | off | on | base |
| Intro_Lever.fbx | Intro_Lever_Handle | 0.6 x 2.582 x 1.076 | 188 | Box | SmoothPlastic | off | on | base |
| Intro_Present_A.fbx | Intro_Present_A | 2.52 x 3.97 x 2.52 | 196 | Box | SmoothPlastic | off | off | base |
| Intro_Present_B.fbx | Intro_Present_B | 3.72 x 2.63 x 2.72 | 196 | Box | SmoothPlastic | off | off | base |
| Intro_Present_C.fbx | Intro_Present_C | 2.72 x 3.43 x 2.72 | 196 | Box | SmoothPlastic | off | off | base |
| Intro_SnowGlobe.fbx | Intro_SnowGlobe | 25.028 x 12.5 x 25.028 | 1008 | Box | SmoothPlastic | off | on | base |
| Intro_SnowGlobe.fbx | Intro_SnowGlobe_Cap | 7.6 x 2.6 x 7.6 | 240 | Box | SmoothPlastic | off | on | base |
| Intro_SnowGlobe.fbx | Intro_SnowGlobe_Glass | 32 x 32 x 32 | 960 | Box | Glass (T 0.55) | off | off | base |
| Intro_SnowGlobe.fbx | Intro_SnowGlobe_Presents | 20.8 x 15.185 x 20.8 | 4044 | Box | SmoothPlastic | off | off | base |
| Intro_Tower.fbx | Intro_Tower | 68.5 x 132.6 x 55.7 | 7088 | Box | SmoothPlastic | off | on | base |
| Intro_Tower.fbx | Intro_Tower_Sign | 13.2 x 12 x 0.65 | 36 | Box | Neon | off | off | base |
| Intro_Tower.fbx | Intro_Tower_Windows | 38.5 x 111.9 x 45.5 | 3240 | Box | Neon | off | off | base |
| Intro_Vacuum.fbx | Intro_Vacuum | 66.817 x 43.378 x 59.295 | 3752 | Box | SmoothPlastic | off | on | base |
| Intro_Vacuum.fbx | Intro_Vacuum_Lights | 50.516 x 15.381 x 38.697 | 584 | Box | Neon | off | off | base |
| JobBoard.fbx | JobBoard | 5.4 x 7.32 x 1 | 844 | Box | SmoothPlastic | off | on | base |
| Lamp_Ceiling.fbx | Lamp_Ceiling | 3.2 x 3.38 x 3.2 | 568 | Box | SmoothPlastic | off | off | base |
| Lamp_Ceiling.fbx | Lamp_Ceiling_Bulb | 0.84 x 0.84 x 0.84 | 120 | Box | Neon | off | off | base |
| LaserEmitter.fbx | LaserEmitter | 1.4 x 10.45 x 1.15 | 428 | Box | SmoothPlastic | on | on | base |
| LaserEmitter.fbx | LaserEmitter_Lens | 0.4 x 8.38 x 0.16 | 200 | Box | Neon | off | off | base |
| LaserEmitter_CandyCane.fbx | LaserEmitter_CandyCane | 3.094 x 11.111 x 1.17 | 888 | Box | SmoothPlastic | on | on | xmas |
| Ornaments.fbx | Ornament_Bauble | 0.96 x 1.355 x 0.96 | 288 | Box | SmoothPlastic | off | off | xmas |
| Ornaments.fbx | Ornament_Bell | 1.04 x 1.345 x 1.04 | 328 | Box | SmoothPlastic | off | off | xmas |
| Ornaments.fbx | Ornament_Donut | 1 x 1.302 x 0.38 | 400 | Box | SmoothPlastic | off | off | xmas |
| Ornaments.fbx | Ornament_Stand | 0.95 x 2.13 x 0.9 | 180 | Box | SmoothPlastic | off | off | xmas |
| Ornaments.fbx | Ornament_Star | 1.046 x 1.19 x 0.2 | 164 | Box | SmoothPlastic | off | off | xmas |
| Ornaments.fbx | Ornament_Van | 1.15 x 0.995 x 0.54 | 280 | Box | SmoothPlastic | off | off | xmas |
| Ornaments.fbx | Ornament_VaultDoor | 1.04 x 1.435 x 0.33 | 472 | Box | SmoothPlastic | off | off | xmas |
| Pedestal_Diamond.fbx | Pedestal_Diamond | 3.2 x 3.4 x 3.28 | 528 | Box | SmoothPlastic | on | on | base |
| Pedestal_Diamond.fbx | Pedestal_Diamond_Case | 2.6 x 2.7 x 2.6 | 60 | Box | Glass (T 0.7) | off | off | base |
| Pediment_24.fbx | Pediment_24 | 24.893 x 6.531 x 2.45 | 228 | Box | SmoothPlastic | off | off | base |
| Pillar_2x12.fbx | Pillar_2x12 | 2.3 x 12 x 2.3 | 324 | Box | SmoothPlastic | on | on | base |
| Plate_4x4.fbx | Plate_4x4 | 4 x 0.36 x 4 | 484 | Box | SmoothPlastic | on | off | base |
| Plate_4x4.fbx | Plate_4x4_Ring | 3.3 x 0.14 x 3.3 | 288 | Box | Neon | off | off | base |
| Present.fbx | Present | 2.101 x 2.021 x 1.9 | 388 | Box | SmoothPlastic | on | off | base |
| Railing_8.fbx | Railing_8 | 8 x 3.6 x 0.24 | 60 | Box | SmoothPlastic | off | off | base |
| Roof_Antenna.fbx | Roof_Antenna | 4.4 x 9 x 1 | 72 | Box | SmoothPlastic | off | off | base |
| Roof_Chimney.fbx | Roof_Chimney | 2.9 x 6.2 x 2.9 | 204 | Box | SmoothPlastic | off | off | base |
| Roof_Gable.fbx | Roof_Gable | 10.4 x 3.62 x 8.6 | 32 | Box | SmoothPlastic | off | off | base |
| Roof_WaterTank.fbx | Roof_WaterTank | 6.3 x 11.8 x 6.3 | 412 | Box | SmoothPlastic | off | off | base |
| Rookie.fbx | Rookie_Face_Idle | 1.119 x 0.775 x 0.273 | 544 | Box | SmoothPlastic | off | off | base |
| Rookie.fbx | Rookie_Head | 2.097 x 1.66 x 1.89 | 644 | Box | SmoothPlastic | off | on | base |
| Rookie.fbx | Rookie_LeftFoot | 0.76 x 0.66 x 1.3 | 152 | Box | SmoothPlastic | off | on | base |
| Rookie.fbx | Rookie_LeftHand | 0.62 x 0.64 x 0.571 | 244 | Box | SmoothPlastic | off | on | base |
| Rookie.fbx | Rookie_LeftLowerArm | 0.609 x 0.754 x 0.533 | 120 | Box | SmoothPlastic | off | on | base |
| Rookie.fbx | Rookie_LeftLowerLeg | 0.7 x 0.64 x 0.666 | 120 | Box | SmoothPlastic | off | on | base |
| Rookie.fbx | Rookie_LeftUpperArm | 0.696 x 1.032 x 0.647 | 180 | Box | SmoothPlastic | off | on | base |
| Rookie.fbx | Rookie_LeftUpperLeg | 0.739 x 0.661 x 0.704 | 80 | Box | SmoothPlastic | off | on | base |
| Rookie.fbx | Rookie_LowerTorso | 1.84 x 0.68 x 1.243 | 184 | Box | SmoothPlastic | off | on | base |
| Rookie.fbx | Rookie_RightFoot | 0.76 x 0.66 x 1.3 | 152 | Box | SmoothPlastic | off | on | base |
| Rookie.fbx | Rookie_RightHand | 0.62 x 0.64 x 0.571 | 244 | Box | SmoothPlastic | off | on | base |
| Rookie.fbx | Rookie_RightLowerArm | 0.609 x 0.754 x 0.533 | 120 | Box | SmoothPlastic | off | on | base |
| Rookie.fbx | Rookie_RightLowerLeg | 0.7 x 0.64 x 0.666 | 120 | Box | SmoothPlastic | off | on | base |
| Rookie.fbx | Rookie_RightUpperArm | 0.696 x 1.032 x 0.647 | 180 | Box | SmoothPlastic | off | on | base |
| Rookie.fbx | Rookie_RightUpperLeg | 0.739 x 0.661 x 0.704 | 80 | Box | SmoothPlastic | off | on | base |
| Rookie.fbx | Rookie_UpperTorso | 2 x 1.27 x 1.625 | 772 | Box | SmoothPlastic | off | on | base |
| Rookie_Faces.fbx | Rookie_Face_Busted | 1.119 x 0.827 x 0.261 | 248 | Box | SmoothPlastic | off | off | base |
| Rookie_Faces.fbx | Rookie_Face_Shocked | 1.119 x 0.983 x 0.262 | 544 | Box | SmoothPlastic | off | off | base |
| Rookie_Faces.fbx | Rookie_Face_Smug | 1.119 x 0.848 x 0.319 | 680 | Box | SmoothPlastic | off | off | base |
| Rookie_Hands.fbx | Rookie_Hand_Left_Fingers1 | 0.352 x 0.35 x 0.132 | 192 | Box | SmoothPlastic | off | off | base |
| Rookie_Hands.fbx | Rookie_Hand_Left_Fingers2 | 0.344 x 0.291 x 0.124 | 384 | Box | SmoothPlastic | off | off | base |
| Rookie_Hands.fbx | Rookie_Hand_Left_Index1 | 0.14 x 0.34 x 0.14 | 64 | Box | SmoothPlastic | off | off | base |
| Rookie_Hands.fbx | Rookie_Hand_Left_Index2 | 0.132 x 0.305 x 0.132 | 128 | Box | SmoothPlastic | off | off | base |
| Rookie_Hands.fbx | Rookie_Hand_Left_Palm | 0.56 x 0.52 x 0.323 | 160 | Box | SmoothPlastic | off | off | base |
| Rookie_Hands.fbx | Rookie_Hand_Left_Thumb1 | 0.156 x 0.328 x 0.186 | 64 | Box | SmoothPlastic | off | off | base |
| Rookie_Hands.fbx | Rookie_Hand_Left_Thumb2 | 0.144 x 0.297 x 0.173 | 128 | Box | SmoothPlastic | off | off | base |
| Rookie_Hands.fbx | Rookie_Hand_Right_Fingers1 | 0.352 x 0.35 x 0.132 | 192 | Box | SmoothPlastic | off | off | base |
| Rookie_Hands.fbx | Rookie_Hand_Right_Fingers2 | 0.344 x 0.291 x 0.124 | 384 | Box | SmoothPlastic | off | off | base |
| Rookie_Hands.fbx | Rookie_Hand_Right_Index1 | 0.14 x 0.34 x 0.14 | 64 | Box | SmoothPlastic | off | off | base |
| Rookie_Hands.fbx | Rookie_Hand_Right_Index2 | 0.132 x 0.305 x 0.132 | 128 | Box | SmoothPlastic | off | off | base |
| Rookie_Hands.fbx | Rookie_Hand_Right_Palm | 0.56 x 0.52 x 0.323 | 160 | Box | SmoothPlastic | off | off | base |
| Rookie_Hands.fbx | Rookie_Hand_Right_Thumb1 | 0.156 x 0.328 x 0.186 | 64 | Box | SmoothPlastic | off | off | base |
| Rookie_Hands.fbx | Rookie_Hand_Right_Thumb2 | 0.144 x 0.297 x 0.173 | 128 | Box | SmoothPlastic | off | off | base |
| Rookie_Outfits.fbx | Rookie_Block_LeftCuff | 0.587 x 0.239 x 0.542 | 80 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Block_RightCuff | 0.587 x 0.239 x 0.542 | 80 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Block_Torso | 2.05 x 0.36 x 1.558 | 192 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Cap_Beanie | 2.18 x 1.02 x 2.18 | 384 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Cap_Bobble | 2.14 x 1.48 x 2.14 | 484 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Cap_Flat | 2.12 x 0.679 x 2.351 | 336 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Cap_Santa | 2.3 x 1.738 x 2.735 | 484 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Cap_Trapper | 2.26 x 1.48 x 2.1 | 284 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Gloves_Knit_Left | 0.645 x 0.256 x 0.63 | 168 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Gloves_Knit_Right | 0.645 x 0.256 x 0.63 | 168 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Gloves_Leather_Left | 0.72 x 0.301 x 0.73 | 132 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Gloves_Leather_Right | 0.72 x 0.301 x 0.73 | 132 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Mask_Eye | 2.02 x 0.713 x 1.763 | 328 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Scarf_Bandana | 1.6 x 0.78 x 1.772 | 256 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Scarf_Chunky | 1.96 x 0.48 x 1.686 | 320 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Scarf_Knot | 1.72 x 0.792 x 1.71 | 284 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Scarf_Long | 1.72 x 1.16 x 1.69 | 224 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Scarf_Long_Tail1 | 0.78 x 0.851 x 1.047 | 36 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Scarf_Long_Tail2 | 1.265 x 0.547 x 1.335 | 72 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Stripes_LeftArm | 0.658 x 0.416 x 0.594 | 160 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Stripes_RightArm | 0.658 x 0.416 x 0.594 | 160 | Box | SmoothPlastic | off | on | base |
| Rookie_Outfits.fbx | Rookie_Stripes_Torso | 2.028 x 0.62 x 1.541 | 384 | Box | SmoothPlastic | off | on | base |
| Rookie_Viewmodel.fbx | Rookie_VM_LeftArm | 0.654 x 1.258 x 0.635 | 460 | Box | SmoothPlastic | off | off | base |
| Rookie_Viewmodel.fbx | Rookie_VM_RightArm | 0.654 x 1.258 x 0.635 | 460 | Box | SmoothPlastic | off | off | base |
| Rug_8x6.fbx | Rug_8x6 | 8.64 x 0.036 x 6 | 264 | Box | SmoothPlastic | off | off | base |
| Safe.fbx | Safe | 3.2 x 3.95 x 2.92 | 452 | Box | SmoothPlastic | on | on | base |
| Safe.fbx | Safe_Door | 2.71 x 2.94 x 0.7 | 548 | Box | SmoothPlastic | on | on | base |
| Shelf_8x2.fbx | Shelf_8x2 | 8.1 x 7.85 x 2.08 | 776 | Box | SmoothPlastic | on | on | base |
| Shelf_Gondola_8x2.fbx | Shelf_Gondola_8x2 | 8 x 7.85 x 2.16 | 744 | Box | SmoothPlastic | on | on | base |
| Shutter_8x10.fbx | Shutter_8x10 | 8.1 x 10.35 x 1.46 | 556 | Box | SmoothPlastic | on | on | base |
| Skyline_Far.fbx | Skyline_Far | 604.401 x 100.949 x 638.695 | 352 | Box | SmoothPlastic | off | off | base |
| Skyline_Far.fbx | Skyline_Far_Windows | 561.626 x 86 x 596.373 | 1236 | Box | Neon | off | off | base |
| Skyline_Near.fbx | Skyline_Near | 316.773 x 55.878 x 323.381 | 292 | Box | SmoothPlastic | off | off | base |
| Skyline_Near.fbx | Skyline_Near_Windows | 288.575 x 44.4 x 297.02 | 996 | Box | Neon | off | off | base |
| Snowman.fbx | Snowman | 4.005 x 6.24 x 2.568 | 724 | Box | SmoothPlastic | off | off | base |
| Storefront_24x12.fbx | Storefront_24x12 | 24 x 12 x 4.75 | 1980 | PreciseConvexDecomposition | SmoothPlastic | on | on | base |
| Storefront_24x12.fbx | Storefront_24x12_Glass | 22.4 x 6.08 x 0.06 | 24 | Box | Glass (T 0.6) | off | off | base |
| StreetLamp.fbx | StreetLamp | 1.5 x 11.05 x 1.4 | 468 | Box | SmoothPlastic | off | on | base |
| StreetLamp.fbx | StreetLamp_Bulb | 0.6 x 1 x 0.571 | 80 | Box | Neon | off | off | base |
| Switch_Wall.fbx | Switch_Wall | 1.6 x 2.52 x 0.84 | 224 | Box | SmoothPlastic | on | on | base |
| Switch_Wall.fbx | Switch_Wall_Lamp | 0.4 x 0.2 x 0.38 | 58 | Box | Neon | off | off | base |
| Switch_Wall.fbx | Switch_Wall_Lever | 0.52 x 1.472 x 1.156 | 172 | Box | SmoothPlastic | off | on | base |
| Teddy.fbx | Teddy | 2.057 x 2.266 x 1.6 | 596 | Box | SmoothPlastic | on | off | base |
| TellerCounter_8x4.fbx | TellerCounter_8x4 | 8.3 x 8.25 x 4.35 | 412 | Box | SmoothPlastic | on | on | base |
| TellerCounter_8x4.fbx | TellerCounter_8x4_Glass | 7.1 x 3.2 x 0.06 | 24 | Box | Glass (T 0.6) | off | off | base |
| Toy.fbx | Toy | 1.586 x 2.8 x 1.19 | 580 | Box | SmoothPlastic | on | off | base |
| ToySoldier.fbx | ToySoldier | 3.5 x 11.32 x 4.02 | 2736 | Box | SmoothPlastic | off | on | base |
| Truss_8.fbx | Truss_8 | 8.187 x 4 x 0.7 | 60 | Box | SmoothPlastic | off | off | base |
| Van.fbx | Van | 14.9 x 7.689 x 7.08 | 1704 | PreciseConvexDecomposition | SmoothPlastic | on | on | base |
| Van.fbx | Van_Paint | 14 x 5.7 x 6.8 | 164 | Box | SmoothPlastic | off | on | base |
| Van.fbx | Van_Shelf | 6 x 4.06 x 0.98 | 124 | Box | SmoothPlastic | off | on | base |
| VanBakery.fbx | VanBakery | 14.9 x 7.999 x 7.04 | 1652 | Box | SmoothPlastic | off | on | base |
| VanBakery.fbx | VanBakery_Paint | 14 x 5.85 x 6.8 | 192 | Box | SmoothPlastic | off | on | base |
| VanCamper.fbx | VanCamper | 14.9 x 7.891 x 7.08 | 2240 | Box | SmoothPlastic | off | on | base |
| VanCamper.fbx | VanCamper_Paint | 14 x 5.15 x 6.8 | 172 | Box | SmoothPlastic | off | on | base |
| VanSecurity.fbx | VanSecurity | 14.9 x 7.786 x 7.06 | 2204 | Box | SmoothPlastic | off | on | base |
| VanSecurity.fbx | VanSecurity_Paint | 14 x 5.3 x 6.8 | 168 | Box | SmoothPlastic | off | on | base |
| VaultDoor.fbx | VaultDoor_Dial | 4.55 x 4.55 x 0.924 | 1104 | Box | SmoothPlastic | off | on | base |
| VaultDoor.fbx | VaultDoor_DialFace | 2.16 x 2.16 x 0.06 | 384 | Box | SmoothPlastic + SA | off | off | base |
| VaultDoor.fbx | VaultDoor_DialRing | 3.5 x 3.5 x 0.24 | 384 | Box | Neon | off | off | base |
| VaultDoor.fbx | VaultDoor_Door | 11.96 x 8.65 x 3.46 | 3832 | Hull | SmoothPlastic | on | on | base |
| VaultDoor.fbx | VaultDoor_Frame | 16 x 12 x 3.7 | 2452 | PreciseConvexDecomposition | SmoothPlastic | on | on | base |
| Wall_4x12.fbx | Wall_4x12 | 4 x 12 x 2 | 196 | Box | SmoothPlastic | on | on | base |
| Wall_8x12.fbx | Wall_8x12 | 8 x 12 x 2 | 284 | Box | SmoothPlastic | on | on | base |
| Wall_Door_8x12.fbx | Wall_Door_8x12 | 8 x 12 x 2.06 | 664 | PreciseConvexDecomposition | SmoothPlastic | on | on | base |
| Wall_Door_8x12.fbx | Wall_Door_8x12_Leaf | 6 x 9.96 x 1.34 | 508 | Box | SmoothPlastic | on | on | base |
| Wall_Window_8x12.fbx | Wall_Window_8x12 | 8 x 12 x 2.5 | 768 | Box | SmoothPlastic | on | on | base |
| Wall_Window_8x12.fbx | Wall_Window_8x12_Glass | 5 x 5 x 0.06 | 12 | Box | Glass (T 0.6) | off | off | base |
| Xmas_Garland_8.fbx | Xmas_Garland_8 | 8.825 x 1.738 x 0.923 | 736 | Box | SmoothPlastic | off | off | xmas |
| Xmas_Lights_8.fbx | Xmas_Lights_8 | 8.24 x 0.857 x 0.25 | 286 | Box | SmoothPlastic | off | off | xmas |
| Xmas_Lights_8.fbx | Xmas_Lights_8_Bulbs | 7.529 x 0.958 x 0.285 | 400 | Box | Neon | off | off | xmas |
| Xmas_SnowCap_8.fbx | Xmas_SnowCap_8 | 8 x 0.67 x 2.5 | 512 | Box | SmoothPlastic | off | off | xmas |
| Xmas_SnowPile.fbx | Xmas_SnowPile | 4.85 x 3.535 x 3.105 | 576 | Box | SmoothPlastic | off | off | xmas |
| Xmas_Tree.fbx | Xmas_Tree | 4.1 x 6 x 3.899 | 312 | Box | SmoothPlastic | off | on | xmas |
| Xmas_Tree.fbx | Xmas_Tree_Lights | 4.119 x 5.64 x 4.033 | 400 | Box | Neon | off | off | xmas |
| Xmas_Wreath.fbx | Xmas_Wreath | 2.826 x 3.56 x 1.135 | 548 | Box | SmoothPlastic | off | off | xmas |

**99 FBX files, 255 MeshParts, 124,466 triangles in all.** Christmas layer: 19 parts.
<!-- kit-table:end -->

---

## Automated path (no Studio): Open Cloud upload + KitService

_Added 2026-11-12 (spike S2 via the fallback). Claude runs all of it; the owner does nothing unless the key or the game owner changes._

**1. Upload (`tools/kit_upload.py`).** One Open Cloud **Model** asset per kit model group (`assets/fbx/<Model>.fbx`), created for the experience owner (user 10346200733) with `POST https://apis.roblox.com/assets/v1/assets` (multipart: `request` JSON `{assetType: "Model", displayName, description, creationContext.creator.userId}` + `fileContent` as `model/fbx`), then `GET /assets/v1/operations/{id}` until `done`. Ids go to `assets/kit_ids.json` after every upload (with the file's sha256, revision and moderation state).

```sh
python3 tools/kit_upload.py --status        # what is uploaded, changed or pending
python3 tools/kit_upload.py --all           # every new or changed FBX (unchanged files are skipped by hash)
python3 tools/kit_upload.py --images        # assets/textures/*.png as Decals (location atlases, dial-face maps)
python3 tools/kit_upload.py --appearances   # the hero SurfaceAppearance as an rbxm Model (built with Lune)
python3 tools/kit_upload.py --gen           # regenerate the Luau data only (no network)
python3 tools/kit_upload.py --sky           # assets/sky Heist City faces + snowflake as Decals (assets/sky/sky_ids.json)
python3 tools/kit_upload.py --resolve-sky   # Decal -> image ids: read-only Luau task on an existing place version
```

- A **changed** FBX updates the **same** asset (`PATCH /assets/v1/assets/{id}`, a new version), so ids never change and `InsertService:LoadAsset` gets the latest version. `--new` makes a fresh asset instead (the old id goes to `history`). Decals cannot be updated: a changed PNG becomes a new Decal.
- Back-off on HTTP 429 / 5xx (Retry-After, else 1, 2, 4 ... 60 s) and a 2 s gap between uploads. Measured Nov 12: 50 groups in 13 minutes with no 429, 6 Decals in under a minute, every asset moderation `Approved`.
- Every run regenerates **`src/server/Kit/KitData.luau`** (manifest + ids, what the server reads) and the table inside `tests/kit_engine.luau`, then formats both with StyLua. `tests/unit/KitData.spec.luau` fails when KitData is stale.
- Key: the Open Cloud key needs `asset:read` + `asset:write` (confirmed working Nov 12). If the game moves to a **group**, the meshes must belong to the group: `python3 tools/kit_upload.py --group <groupId> --new --force --all --images`, then commit the new ids.

**2. What an upload gives (measured in a real server, Open Cloud Luau Execution).** `InsertService:LoadAsset(id)` returns `Model` > `Model "EH Kit <Model>"` (the display name) > one `MeshPart` per Blender object, named as in the manifest. Sizes match the manifest exactly (studs, no 100x problem) and every part sits at its scene position (origin + bounds centre: the axes are right, so the Vault faces -Z and Gus's torch is on +X). But: `CollisionFidelity = Default` on every part, `PivotOffset` has the right position with a **rotated basis** (Z-up to Y-up), `Anchored = false`, Material `Plastic`, a grey Color. The embedded atlas is uploaded once and shared (one image id for every atlas piece); the dial face brings its own colour map.

**3. Load at boot (`src/server/Kit/KitService.luau`).** Not wired into the heist server yet (the wiring agent does that).

1. `InsertService:LoadAsset` per group (pcall, 4 tries with back-off, 6 at a time). If `ServerStorage/Kit` already holds MeshParts (the manual `Kit.rbxm` path), it uses those instead.
2. Pieces are found through a **MeshPart name map** (`KitLib.nameMap`), never `FindFirstChild(name, true)`, which can return a Model of the same name.
3. **Collision.** Runtime cannot change `CollisionFidelity`, so every part whose fidelity differs from the manifest is **rebuilt** with `AssetService:CreateMeshPartAsync(mesh.MeshContent, {CollisionFidelity = <manifest>})`, keeping name, size, CFrame and texture. Chosen over an invisible Box collider with the mesh `CanCollide = false`: the rebuild also gives `Hull` (vault door) and `PreciseConvexDecomposition` (vault frame, door frame, both street fronts, van), and a piece stays one part, so `part:PivotTo` on a door leaf, the safe door or a Gus limb moves its collision too. If a rebuild fails, the part keeps `Default` and is listed in `report().fidelityKept`. `Config.Kit.REBUILD_FIDELITY` = `"all"` (default) / `"colliding"` / `"none"`.
4. Runtime look, as the prepare script does it: Anchored, CanCollide (CanTouch the same), CastShadow, Material, Color (Neon idle, glass tint, ornament default, else white), Transparency, **one** atlas `TextureID` on atlas pieces (none on Neon and glass), and `PivotOffset` from the manifest bounds (resets the rotated basis). `KitPiece` attribute = the piece name.
5. Every size is checked against the manifest (`Config.Kit.SIZE_TOLERANCE`, 0.05) and every centre against origin + bounds centre (`POSITION_TOLERANCE`).

Measured boot (real server, Nov 12): **2.1 to 2.5 s** for all 92 pieces from 50 assets, including the 92 rebuilds (Box, Hull and PreciseConvexDecomposition) and the hero appearance. That is about the 2.0 s estimate below; it runs once per server, never per heist.

| API (server) | What it does |
|---|---|
| `KitService.start()` | Begins loading in the background (idempotent; `ready()` calls it). |
| `KitService.ready(timeout?) -> boolean` | Yields until loaded (default `Config.Kit.READY_TIMEOUT`); true when every piece is in the library and no size is off. |
| `KitService.isReady() -> boolean` | Loaded yet (no yield). |
| `KitService.has(name)` | Is the piece in the library (else fall back to greybox). |
| `KitService.clone(name, opts?) -> MeshPart?` | One piece at its scene position; place it with `part:PivotTo(cf)`. |
| `KitService.cloneModel(model, opts?) -> Model?` | A whole group (e.g. `VaultDoor`, `Gus`); `WorldPivot` = the group's scene origin, place it with `Model:PivotTo(cf)`. |
| `KitService.spec(name)` | The manifest entry (size, boundsMin/Max, origin, flags, colour). |
| `KitService.names()` / `report()` / `summary()` | Library contents, the boot report, one log line. |
| `KitService.atlas(location?)` | Atlas URI for `"Bank"`, `"CornerShop"`, `"ToyShop"` (Bank when a location atlas is not uploaded). |

`opts = { atlas = "CornerShop", color = Color3 }`: `atlas` swaps the texture on atlas pieces only (STYLE_BIBLE §1.4), `color` tints (tintable ornaments). Templates live in `ServerStorage/Kit/<Model>`.

**Atlas ids.** The Bank atlas also comes with the FBX upload. The location swaps (`EH_Palette_CornerShop`, `EH_Palette_ToyShop`) and the dial-face maps are uploaded as Decals (`--images`). A Decal id is not an image id: `LoadAsset(decalId)` returns a Model with a `Decal` whose `Texture` is the image (measured). `kit_ids.json` records each image id (`--set-image <stem> <imageId>`, done for all six on Nov 12); KitService resolves any unrecorded one at boot the same way. `Config.Kit.Atlas.<Location>` overrides any of them. Nov 12 ids: Bank `125339359087334`, CornerShop `108976991965311`, ToyShop `77723873181805` (navy), replaced on Nov 13 by the warm berry-plum walls: Decal `92072228703618`, image `90000315473532`.

**Hero SurfaceAppearance.** Runtime scripts **cannot** write SurfaceAppearance maps (`ColorMapContent`: "lacking capability Plugin", measured), but they can load, clone and parent one. So `--appearances` builds `KitAppearances.rbxm` with Lune (one SurfaceAppearance per manifest piece with a `texture`, named after the piece: colour, roughness and emissive mask = the uploaded image ids, EmissiveStrength 2, EmissiveTint = the dial ring's idle colour), uploads it as a Model, and KitService clones it onto `VaultDoor_DialFace` (and clears its TextureID). Level code may still set `EmissiveTint` at runtime (it follows `VaultDoor_DialRing.Color`). Without the asset, the dial face keeps the colour map the FBX import made.

**4. Check in the real engine (`tests/kit_engine.luau`).**

```sh
ROBLOX_API_KEY=proxy-injected python3 tools/cloud_test.py --universe 10776026960 --place 70772627070328 \
  --version <N> --script tests/kit_engine.luau
```

Part A loads every id from the embedded table and checks counts, sizes and centres, the Decals and the appearances asset, and reports what the upload gave. Part B runs KitService (when that place version contains it) and checks every clone's size, fidelity, flags and pivot, every group model, `PivotTo`, the atlas and the hero appearance.

Results, Nov 12: place version **17** (published once, with KitService) **246/246**; the current code (with the hero appearance, which v17 predates) run as a bundled copy on v17: **248/248**, `92/92 pieces (cloud, 50 groups) in 2.1 s; rebuilt 92 for collision; 0 missing, 0 size errors, 0 position errors, 0 off-fidelity; atlas rbxassetid://125339359087334 (uploaded EH_Palette_Bank); hero SurfaceAppearance`. On v17 itself the hero check fails until the next publish carries the new module.

**When the art changes:** `python3 tools/blender/build_asset.py --all`, `python3 tools/blender/kit_docs.py`, then `python3 tools/kit_upload.py --all` (only changed files go up, same ids). A changed PNG: `--images`, then `--set-image` with the id the engine check prints, then `--appearances` if a dial-face map changed. Then run the engine check.

---

## Before you start

1. Pull the repo, so `assets/fbx/` has every `.fbx` file and `assets/textures/` has the images.
2. Open Roblox Studio. Make a **new Baseplate place** called `KitWorkshop`. Do not use the live place or the test place.
3. Know who owns the game. The meshes and images must belong to the **same owner as the experience** (you, or your group). Otherwise they do not load in the game.

## Step 1. Import each FBX file (Import 3D)

Do this once for each file in `assets/fbx/` (you can select several files at once).

1. Click **Home > Import 3D** and choose the file(s).
2. In the import window, under **File General**, set:
   - **Name**: keep the file name, for example `VaultDoor`. Code finds pieces by name.
   - **Upload to Roblox**: **ON**. This is needed: the saved file only keeps a link to the uploaded mesh.
   - **Creator**: the owner of the experience (you or your group).
   - **Import Only As Model**: ON.
   - **Set Pivot to Scene Origin**: ON.
   - **Insert Using Scene Position**: ON.
   - **Anchored**: ON.
3. Under **File Transform**, set:
   - **World Forward**: Front.
   - **World Up**: Top.
   - **Scale Unit**: **Studs**.
   - **Merge Meshes**: **OFF**. Merged meshes lose their names and pivots (Gus needs his 18 separate parts and their pivots).
4. Select each child in the list on the left. Check that **Use Imported Pivot** is ON. Check that **Make Double Sided** and **Ignore Vertex Colors** are OFF.
5. Look at **File Geometry**. The size must match the table above. A wall is 8 x 12 x 2, not 800 x 1200 x 200. If it is 100 times too big, stop and tell Claude: the export setting is wrong.
6. Read the warnings panel. "Non-manifold" must not appear. Then click **Import**.

## Step 2. Put everything in one folder

1. In the Explorer, make a **Folder** in Workspace called **`Kit`**. Use this exact name, with a capital K.
2. Drag every imported Model into `Kit`. If a Model is called `Scene`, rename it to its file name. Many MeshParts have
   the same name as their Model (`CashBag` inside `CashBag`, `Safe` inside `Safe`): that is expected, keep it.
3. **Never resize or rotate a piece in Studio.** A wrong size is fixed in Blender, not in Studio.

## Step 3. Upload the images (once per art revision)

Upload these PNG files with the **Asset Manager > Import** (or **Create > Decals**) under the experience owner, and copy each id:

| File | What it is | Where the id goes |
|---|---|---|
| `assets/textures/EH_Palette_Bank.png` | The kit atlas (the importer usually uploads it too) | `ATLAS` at the top of the prepare script; `Config.Kit.Atlas.Bank` |
| `assets/textures/EH_Palette_CornerShop.png` | Corner Shop atlas swap (brick walls, pine wood) | `Config.Kit.Atlas.CornerShop` (tell Claude) |
| `assets/textures/EH_Palette_ToyShop.png` | Toy Shop atlas swap (Drop 1, Dec 11) | `Config.Kit.Atlas.ToyShop` (tell Claude) |
| `assets/textures/VaultDoor_DialFace_Color.png` | Vault combination face colour map (1024) | `DIALFACE_COLOR` in the prepare script |
| `assets/textures/VaultDoor_DialFace_Roughness.png` | Its roughness map | `DIALFACE_ROUGHNESS` |
| `assets/textures/VaultDoor_DialFace_Emissive.png` | Its emissive mask (the numbers and ticks glow) | `DIALFACE_EMISSIVE` |

The location look is an **atlas swap**: every kit piece keeps the same mesh and UVs, and code sets `MeshPart.TextureID` to the location's atlas id when it builds a level (STYLE_BIBLE §1.4). So the kit itself only ever uses the Bank atlas.

## Step 4. Run the prepare script (command bar)

1. Open `docs/art/KitPrepare.commandbar.lua` (generated; do not edit it by hand except for the ids at the top).
2. Paste the ids from Step 3 into its first lines. A bare number (`123456789`) is fine: the script adds `rbxassetid://`.
3. In the Explorer, select the `Kit` folder. Paste the whole script into **View > Command Bar** and press Enter.

The script finds every piece among the `MeshPart`s under `Kit` (by name, and checks it sits in the right Model; it never uses `FindFirstChild(name, true)`, which returns a Model of the same name). It warns about duplicate names and pieces the manifest does not know. Then it gives every piece its look: SmoothPlastic, Color white, the one atlas texture, Anchored, CanCollide and CastShadow from the table. Runtime-tinted parts (Neon rings, lenses, bulbs) get no texture and their idle colour (`eh_palette.NEON`); glass parts get Glass and their transparency; the three tintable ornaments get the atlas and their default colour. It removes any SurfaceAppearance the importer made, except on `VaultDoor_DialFace`, where it builds the hero SurfaceAppearance (colour, roughness, emissive mask). Then it prints a check line per piece and two axis checks:

- `Vault front faces -Z: yes` (the dial is on the frame's LookVector side).
- `Gus torch on his right (+X): yes` (the export turns Blender -X into Roblox +X; this line proves it).

If either says NO, stop and tell Claude: the FBX axis setting must change before anything is placed.

## Step 5. Set collision by hand (scripts cannot do this)

Roblox builds the collision shape when the part is made, so set it in the Properties window:

1. Select every piece whose table row says **Box** and set **CollisionFidelity = Box** (most pieces).
2. **Hull**: `VaultDoor_Door`.
3. **PreciseConvexDecomposition**: `VaultDoor_Frame` (round opening), `Wall_Door_8x12` (6 x 10 opening), `Storefront_24x12` and `BankFront_24x12` (8 x 10 entrances), `Van` (open cargo bay).
4. Run the script from Step 4 again. It must print **KIT OK**.

To see the collision shapes: **File > Studio Settings > Physics > Show Decomposition Geometry**. Walk an avatar through the vault opening, the door frame and both street entrances: you must not get stuck.

## Step 6. Save the file

1. Right-click the `Kit` folder and choose **Save to File...**.
2. Choose the repo folder `assets/` and the name **`Kit.rbxm`**. Binary `.rbxm`, not `.rbxmx`.
3. The file should be well under 1 MB: the meshes stay on Roblox, the file only links to them.
4. Tell Claude: "Kit.rbxm is saved", plus the atlas ids from Step 3.

## Step 7. What Claude does next (you do not need to do this)

1. Copies the node from `kit.project.snippet.json` into `default.project.json` (`"ServerStorage": { "Kit": { "$path": "assets/Kit.rbxm" } }`). Not before the file exists: Rojo stops when a `$path` is missing.
2. Runs `rojo build -o build/EchoHeist.rbxlx` and `lune run tests/kit_check.luau build/EchoHeist.rbxlx`. The check compares the built place with `kit_manifest.json`: names, sizes, Material, CanCollide, CastShadow, a mesh link on every part, one shared atlas. Lune cannot read `CollisionFidelity`, so it only warns; your Step 5 check is the proof. `tests/kit_check.luau` finds pieces the way the prepare script does (a name map of the `MeshPart` descendants, plus a check that each sits in its manifest `model`), so the pieces that share their Model's name are found (fixed in the Nov 12 integration check; verified in Lune on a synthetic kit place).
3. Runs the Open Cloud smoke test (`tools/cloud_test.py`): the server clones kit pieces and checks size and collision in the real engine.

---

## How the game uses the kit (for the level layout code)

Everything below is also in `kit_manifest.json` per part: `tags`, `layer`, `sim`, `joint`, `origin` / `boundsMin` / `boundsMax` (Roblox axes, relative to the pivot), and extras (`opening`, `niche`, `open`, `grips`, `hooks`, `ornamentScale`, `hangPoint`, `tintable`). The manifest root also has `neon` (idle and runtime colours) and `ornamentDays`.

**Place kit pieces only with `PivotTo` / `GetPivot`, never by setting `.CFrame` or `.Position`.** A MeshPart's `CFrame` is the centre of its bounding box; the imported pivot (the kit point: wall corner, hinge, joint, hang point) lives in `PivotOffset`. Setting `.CFrame` to a pivot position shifts the piece by its centre-to-pivot offset (for a wall, half a module). `Model:PivotTo(cf)` for a whole piece; `part:PivotTo(cf)` for one part (a leaf, a Gus limb).

**Module space.** Each piece's pivot is its kit point. In Roblox axes a wall-line module spans **X from -W to 0** from its pivot (the pivot is the module's left end seen from the front; Blender's +X became Roblox -X), Y 0..12, Z 0..2 (front face on Z = 0, facing -Z). Everything below uses `CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yaw), 0)`.

**Walls are centred on their grid line (STYLE_BIBLE §5.2).** The sim's walls are 1 thick on the line (line ± 0.5); a kit wall is 2 thick on the same line (line ± 1), so the kit covers every sim wall box with 0.5 to spare on both faces: an actor can never reach a sim wall (solid to physics wherever the sim is solid). This holds for shell walls, partitions, door frames, windows, both street fronts and the vault frame. For a run of length W from `a` to `b`:

| Wall along | Front faces | Model pivot | yaw |
|---|---|---|---|
| X on line z = Z0 | -Z | (b, 0, Z0 - 1) | 0 |
| X on line z = Z0 | +Z | (a, 0, Z0 + 1) | 180 |
| Z on line x = X0 | -X | (X0 - 1, 0, a) | 90 |
| Z on line x = X0 | +X | (X0 + 1, 0, b) | -90 |

Plain walls are dressed on both faces, so their facing does not matter; it does for `Storefront_24x12`, `BankFront_24x12` (front = the **street**) and `VaultDoor` (front = the dial side). A **street front** with the street at +Z (Shop.shell, Bank.shell): pivot **(-12, 0, zLine + 1), yaw 180** spans x -12..12 with the entrance on -4..4; a `Wall_4x12` (shop) or `Wall_8x12` (bank) fills each side to the corners. A **Pillar_2x12** is centred on every outside corner (grid corner (gx, gz): pivot (gx + 1, 0, gz - 1)); it hides where the two walls meet. Floors: `Floor_8x8`'s pivot is its top front-left corner (walking surface at y = 0); tiles run under the walls.

**LevelSpec boxes vs kit pieces.**

<!-- fit-table:start -->
Boxes and footprints are **X range, Z range in Roblox world studs** (Y is up; heights are left out). "Fit" lists, per side, how far the sim box reaches past the kit piece (+) or the kit past the box (-). Generated from `kit_manifest.json` and the level data by `tools/blender/kit_docs.py`.

| Level item | Sim box | Kit piece and placement (Model pivot X, Y, Z; yaw) | Kit footprint | Fit (+ box past kit) | Verdict |
|---|---|---|---|---|---|
| Shell wall (L1 west, x = -16) | X -16.5..-15.5, Z -34..10 | `Wall_8x12` pivot (-17, 0, -8), yaw 90 | X -17..-15, Z -8..0 | -X -0.50, +X -0.50 | Kit covers the sim wall (the safe direction) |
| Partition (L2, z = -20) | X -16.5..-3, Z -20.5..-19.5 | `Wall_8x12` pivot (-4, 0, -21), yaw 0 | X -12..-4, Z -21..-19 | -Z -0.50, +Z -0.50 | Kit covers the sim wall (the safe direction) |
| Front wall beside the storefront (L1, z = 10) | X -16.5..-4, Z 9.5..10.5 | `Wall_4x12` pivot (-16, 0, 11), yaw 180 | X -16..-12, Z 9..11 | -Z -0.50, +Z -0.50 | Kit covers the sim wall (the safe direction) |
| Door frame (L1 BackRoom door) | X -3..3, Z -20.5..-19.5 | `Wall_Door_8x12` pivot (4, 0, -21), yaw 0 | opening X -3..3 | - | Exact |
| Door leaf (L1 BackRoom door) | X -3..3, Z -20.5..-19.5 | `Wall_Door_8x12_Leaf` pivot (4, 0, -21), yaw 0 | X -3..3, Z -20.67..-19.33 | -Z -0.17, +Z -0.17 | Kit covers the box; kit wider by -Z 0.17, +Z 0.17: solid to physics where the sim is open (safe) |
| Storefront entrance (L5 Shutter) | X -4..4, Z 9.5..10.5 | `Storefront_24x12` pivot (-12, 0, 11), yaw 180 | opening X -4..4 | - | Exact |
| Shutter (L5 Shutter, DV09 Shutter) | X -4..4, Z 9.5..10.5 | `Shutter_8x10` pivot (0, 10.35, 10), yaw 180 | X -4.05..4.05, Z 9.27..10.73 | -X -0.05, +X -0.05, -Z -0.23, +Z -0.23 | Kit covers the box; kit wider by -X 0.05, +X 0.05, -Z 0.23, +Z 0.23: solid to physics where the sim is open (safe) |
| Bank front entrance (L6 FrontDoors) | X -4..4, Z 9.5..10.5 | `BankFront_24x12` pivot (-12, 0, 11), yaw 180 | opening X -4..4 | - | Exact |
| Shutter (L6 FrontDoors) | X -4..4, Z 9.5..10.5 | `Shutter_8x10` pivot (0, 10.35, 10), yaw 180 | X -4.05..4.05, Z 9.27..10.73 | -X -0.05, +X -0.05, -Z -0.23, +Z -0.23 | Kit covers the box; kit wider by -X 0.05, +X 0.05, -Z 0.23, +Z 0.23: solid to physics where the sim is open (safe) |
| Vault frame (L6 VaultDoor) | X -3..3, Z -48.5..-47.5 | `VaultDoor_Frame` pivot (-8, 0, -47), yaw 180 | opening X -2.7..2.7 | - | Kit opening narrower by 0.30 / 0.30 (solid to physics where the sim is open: the safe direction) |
| Vault door OPEN (L6) | X -3..3, Z -48.5..-47.5 | `VaultDoor_Door` pivot (-8, 0, -47), yaw 180, open yaw -175 at the hinge | X -17.6..-5.3, Z -46.8..-42.25 | - | **CONFLICT: the open door rests on plate C (4.0 x 1.8), hide WestStack (6.0 x 2.8)** (CanCollide is off while open, but it covers them visually): content track, move them >= 3 studs north |
| Plate (L1 A) | X 8..12, Z -10..-6 | `Plate_4x4` pivot (10, 0, -8), yaw 0 | X 8..12, Z -10..-6 | exact | Exact |
| Laser post (L3 Grid, west end) | X -15.5..15.5, Z -34.5..-33.5 | `LaserEmitter` pivot (-15, 0, -34), yaw -90 | X -15..-13.85, Z -34.7..-33.3 | -X +0.50, -Z -0.20, +Z -0.20 | Post on the wall face, lens toward +X; beams by code from lens to lens. The box's last 0.5 is inside the wall |
| Counter (L2-L4, west wall) | X -15.5..-11, Z -4..0 | `Counter_4x4` pivot (-11, 0, 0), yaw -90 | X -15.15..-10.85, Z -4.15..0.15 | -X +0.35, +X -0.15, -Z -0.15, +Z -0.15 | Kit covers the box (the box's -X end is inside the wall); kit wider by +X 0.15, -Z 0.15, +Z 0.15: solid to physics where the sim is open (safe) |
| Counter (L1) | X -13..-7, Z -4..0 | `Counter_8x4` pivot (-14, 0, 0), yaw 180 | X -14.15..-5.85, Z -4.15..0.15 | -X -1.15, +X -1.15, -Z -0.15, +Z -0.15 | Kit covers the box; kit wider by -X 1.15, +X 1.15, -Z 0.15, +Z 0.15: solid to physics where the sim is open (safe). Content track: widen the L1 counter box to X -14..-6 to match the 8-wide module |
| Counter + till (L5, west wall) | X -15.5..-10, Z -3..1 | `Counter_8x4` pivot (-15, 0, 1), yaw 180 | X -15.15..-6.85, Z -3.15..1.15 | -X +0.35, +X -3.15, -Z -0.15, +Z -0.15 | Kit covers the box (the box's -X end is inside the wall); kit wider by +X 3.15, -Z 0.15, +Z 0.15: solid to physics where the sim is open (safe). The till (Register loot at X -8.5, Z -1) sits on the counter's east end, outside the box: content track, widen the box to X -15.5..-7 (or move the till to X <= -10.5) |
| Lobby counter run (L6, west half, 1 of 2 modules) | X -19.5..-3, Z -6..-4 | `Counter_8x2` pivot (-11, 0, -4), yaw 180 | X -11.15..-2.85, Z -6.15..-3.85 | -Z -0.15, +Z -0.15 | Kit covers the sim wall (the safe direction) |
| Aisle shelf (L5 west row, 1 of 2 modules) | X -9..-7, Z -22..-6 | `Shelf_Gondola_8x2` pivot (-9, 0, -22), yaw 90 | X -9.08..-6.92, Z -22..-14 | -X -0.08, +X -0.08 | Kit covers the sim wall (the safe direction) |
| Pillar (L6 StaffPillar) | X 2..4, Z -18..-16 | `Pillar_2x12` pivot (4, 0, -18), yaw 0 | X 1.85..4.15, Z -18.15..-15.85 | -X -0.15, +X -0.15, -Z -0.15, +Z -0.15 | Kit covers the box; kit wider by -X 0.15, +X 0.15, -Z 0.15, +Z 0.15: solid to physics where the sim is open (safe) |
| Hide: L4 Crate | X 3.5..7.5, Z -35.5..-32.5 | `Hide_Crate` pivot (5.8, 0, -33.63), yaw 180 | X 3.28..7.72, Z -35..-32.26 | -X -0.22, +X -0.22, -Z +0.50, +Z -0.24 | Inside the box |
| Hide: L4 CoatRack (plate B) | X -15..-9, Z -26..-20.5 | `Hide_CoatRack` pivot (-12, 0, -23), yaw 0 | X -15..-9, Z -25.4..-20.6 | -Z +0.60, +Z +0.10 | Plate B ring inside the open niche (visible) |
| Hide: DV09 CoatRack (plate A) | X 7..13, Z -11..-5 | `Hide_CoatRack` pivot (10, 0, -8), yaw 0 | X 7..13, Z -10.4..-5.6 | -Z +0.60, +Z +0.60 | Plate A ring inside the open niche (visible) |
| Hide: L6 Fern (plate B; DV10, DV12 same) | X -19.5..-13, Z -21..-14.5 | `Hide_Plant` pivot (-16, 0, -18), yaw 90 | X -18.98..-13.02, Z -21.15..-14.85 | -X +0.52, +X +0.02, -Z -0.15, +Z +0.35 | Plate B ring inside the open niche (visible) |
| Hide: L6 WestStack (plate C) | X -16..-10, Z -45..-39 | `Hide_DepositStack` pivot (-13, 0, -42), yaw 180 | X -16.12..-9.88, Z -45.12..-38.77 | -X -0.12, +X -0.12, -Z -0.12, +Z -0.23 | Plate C ring inside the open niche (visible) |
| Hide: L6 EastStack (plate D) | X 10..16, Z -45..-39 | `Hide_DepositStack` pivot (13, 0, -42), yaw 180 | X 9.88..16.12, Z -45.12..-38.77 | -X -0.12, +X -0.12, -Z -0.12, +Z -0.23 | Plate D ring inside the open niche (visible) |
| Hide: L6 CoatStand | X 13.5..18.5, Z -19.5..-14.5 | `Hide_CoatStand` pivot (16, 0, -17), yaw 90 | X 13.93..18.6, Z -19.37..-14.63 | -X +0.43, +X -0.10, -Z +0.13, +Z +0.13 | Inside the box |
| Hide: DV12 CoatStand | X 13..19.5, Z -21..-14.5 | `Hide_CoatStand` pivot (16.25, 0, -17.75), yaw 90 | X 14.18..18.85, Z -20.12..-15.38 | -X +1.18, +X +0.65, -Z +0.88, +Z +0.88 | Inside the box |
| Hide: DV04 Tree (Christmas layer piece) | X -15.5..-10.5, Z -26.5..-21.5 | `Xmas_Tree` pivot (-13, 0, -24), yaw 0 | X -15.05..-10.95, Z -25.95..-22.05 | -X +0.45, +X +0.45, -Z +0.55, +Z +0.55 | A Christmas-layer piece: DV04 needs the dressing on while it is live |
| Hide: L6 TellerDesk (plate A) | X -15..-9, Z -13..-7 | none | - | - | **No kit piece reads as cover here.** Plate A (X -14..-10, Z -12..-8) sits in the box, behind the 3.5-tall lobby counter: a 5.2 avatar shows above it. Suggest a `Hide_DepositStack` (open side to the counter) or a `Hide_CoatStand`: content-track call |
<!-- fit-table:end -->

Things the **content track** has to change in the level data (the kit cannot fix them): the L1 counter box (6 wide; the module is 8), the L5 till outside its counter box, the open vault door resting on L6's WestStack / plate C, and a cover piece for L6's TellerDesk hide.

**Hides.** Every hide prop is walk-in (CanCollide off; the sim box decides). Hides with a plate under them keep a **4 x 4 open floor niche** at their centre (manifest `niche`): place the piece with its niche centre on the plate centre. `Hide_Plant` (two planters, fronds arching over the open ends: open toward the room), `Hide_CoatRack` (stand between the two rows of coats), `Hide_DepositStack` (a U of deposit-box towers, open on -Z), `Hide_CoatStand` (a ring of coats, open on -Z), `Hide_Crate` (back on the wall face), `Hide_Curtain` (on a wall face).

**Loot kinds.** One mesh per LevelSpec `kind` (generated from the level data; the build fails if a kind has no mesh):

<!-- loot-table:start -->
| Loot kind | Kit mesh | Placed in | Shown as |
|---|---|---|---|
| Candy | `Candy` | 35 in 14 level(s) | carried; on window displays and shelf boards (dark tops only) |
| Cash | `CashBag` | 10 in 6 level(s) | carried; a till (`top` Register) is `CashRegister` + `CashRegister_Drawer` |
| Diamond | `Diamond` | no launch level yet | on `Pedestal_Diamond` (+ `_Case`); hovers 1.25 above the cushion |
| Gold | `GoldBar` | 7 in 6 level(s) | carried; on display a `GoldStack` (L6 Gold: the stack on a dark pedestal or Counter_8x2 top) |
| Present | `Present` | 17 in 12 level(s) | carried (daily vaults); heavy loot (`heavy`) is `GiantPresent` with 4 `grips` |
| Teddy | `Teddy` | 6 in 1 level(s) | carried; on `Shelf_Gondola_8x2` boards (L5 back rows) |
| Toy | `Toy` | 6 in 1 level(s) | carried; on `Shelf_Gondola_8x2` boards (L5) |
<!-- loot-table:end -->

**Doors.** `Wall_Door_8x12_Leaf` is a pocket door: it slides 6 studs along its local -X into the wall beside it (needs a solid wall ≥ 6 wide there). `Shutter_8x10` is the LOCKDOWN leaf of the 8 x 10 street entrances (L5 Shutter, L6 FrontDoors, DV09 Shutter): its pivot is its top centre, 0.35 inside the header, on the wall's centre plane (pivot (0, 10.35, zLine), yaw 180 for a +Z street). Rolled up = `Size.Y` 0.35 with the top pinned (hidden in the header) and CanCollide off; the drop tweens `Size.Y` to 10.35, re-pivoting each step (`part:PivotTo(top)`, the size changes about the centre). `Safe_Door` swings -100° about its hinge pivot.

**Vault door.** `VaultDoor_Door` opens **outward** (toward the front, -Z) by **-175° about its hinge pivot** and comes to rest along the wall face on the viewer's left (+X): `door:PivotTo(hinge * CFrame.Angles(0, math.rad(-175), 0))`, and `VaultDoor_Dial`, `_DialFace`, `_DialRing` follow with the same hinge transform (`open.follow`). During the swing it sweeps a half disc of radius 11.4 in front of the wall around the hinge; at rest it covers module-local X -2.7..9.6, Z -4.75..-0.2 (`open.footprintMin/Max`). It is CanCollide **on only while shut** (the sim's 6 x 10 door box); from the first frame of opening until it is shut again it is visual only, so it never blocks anyone the sim lets through. Keep plates, hides and loot out of the resting footprint (the fit table checks L6).

**Christmas layer.** Pieces with `layer = "xmas"`: `Xmas_*`, `Ornament_*`, `LaserEmitter_CandyCane` (swaps the post, keeps `LaserEmitter_Lens`) and `Gus_SantaHat` (weld at `HatAttach` on `Gus_Head`, hide `Gus_Cap`). The server clones them only while the dressing is on (server date, MASTERPLAN §4.3). Wall dressing (`Xmas_Garland_8`, `Xmas_Lights_8`, `Xmas_SnowCap_8`) uses the pivot of the wall module it dresses; snow caps go on exterior walls only. `Present` loot is not dressing: it is layer base (the daily vaults keep it after the season).

**Advent ornaments.** Each advent day has its own look (`ornamentDays` in the manifest, from `eh_palette.ORNAMENT_DAYS`): `Ornament_Bauble`, `_Bell` and `_Star` are tintable (drawn on the tint cell: set `MeshPart.Color`), `_VaultDoor`, `_Donut` and `_Van` keep their colours (Color white). On the tree, ornaments hang at **0.65 size** (`ornamentScale`: `Size * 0.65`, then `PivotTo` the hook; their pivot is the hang point); on the shelf `Ornament_Stand`, full size. `Orn_Vault<NN>` looks like the advent ornament of the day design NN first played (Dec 2 + NN). Decorated tree: `docs/art/turntables/KitPreview_Tree.png`.

<!-- ornament-table:start -->
| Dec | Trophy id | Mesh | MeshPart.Color |
|---|---|---|---|
| 3 | `Orn_Advent2026_03` | `Ornament_VaultDoor` | `#FFFFFF` (fixed colours: keep white) |
| 4 | `Orn_Advent2026_04` | `Ornament_Bauble` | `#8C2F4B` |
| 5 | `Orn_Advent2026_05` | `Ornament_Star` | `#EDE2C8` |
| 6 | `Orn_Advent2026_06` | `Ornament_Bell` | `#2FBF71` |
| 7 | `Orn_Advent2026_07` | `Ornament_Bauble` | `#C0C3D5` |
| 8 | `Orn_Advent2026_08` | `Ornament_Star` | `#2FBF71` |
| 9 | `Orn_Advent2026_09` | `Ornament_Bell` | `#A8987A` |
| 10 | `Orn_Advent2026_10` | `Ornament_Bauble` | `#1C7C48` |
| 11 | `Orn_Advent2026_11` | `Ornament_Star` | `#8C2F4B` |
| 12 | `Orn_Advent2026_12` | `Ornament_Bell` | `#EDE2C8` |
| 13 | `Orn_Advent2026_13` | `Ornament_Donut` | `#FFFFFF` (fixed colours: keep white) |
| 14 | `Orn_Advent2026_14` | `Ornament_Bauble` | `#7C86A6` |
| 15 | `Orn_Advent2026_15` | `Ornament_Star` | `#C0C3D5` |
| 16 | `Orn_Advent2026_16` | `Ornament_Bell` | `#7C86A6` |
| 17 | `Orn_Advent2026_17` | `Ornament_Bauble` | `#A8987A` |
| 18 | `Orn_Advent2026_18` | `Ornament_Star` | `#1C7C48` |
| 19 | `Orn_Advent2026_19` | `Ornament_Bell` | `#C0C3D5` |
| 20 | `Orn_Advent2026_20` | `Ornament_Bauble` | `#2FBF71` |
| 21 | `Orn_Advent2026_21` | `Ornament_Star` | `#7C86A6` |
| 22 | `Orn_Advent2026_22` | `Ornament_Bell` | `#8C2F4B` |
| 23 | `Orn_Advent2026_23` | `Ornament_Bauble` | `#EDE2C8` |
| 24 | `Orn_Advent2026_24` | `Ornament_Van` | `#FFFFFF` (fixed colours: keep white) |
<!-- ornament-table:end -->

**Gus.** 18 parts (15 R15 body parts + `Gus_Cap`, `Gus_Flashlight`, `Gus_FlashlightLens`). Each part's pivot is its joint with `joint.parent`. At rest every pivot is axis-aligned, so the rest offset is `C0 = CFrame.new(origin[child] - origin[parent])` (manifest `origin`, Roblox axes). The pose player sets **`part:PivotTo(parent:GetPivot() * C0 * pose)`**, parents before children. Never `part.CFrame = ...`: `Gus_Head`'s centre is 0.7 above its Neck pivot and `Gus_Flashlight`'s is about 0.6 in front of the grip, so a CFrame-based pose spins each limb about its centre and drifts it. With Motor6Ds instead: `Part0 = parent`, `Part1 = child`, `C0 = parent.PivotOffset * C0rest`, `C1 = child.PivotOffset`, and the pose goes in `Transform`. The Torch Amber cone starts at the lens (MASTERPLAN §6.5).

**Hero SurfaceAppearance.** Only `VaultDoor_DialFace` (STYLE_BIBLE §4: ≤ 3 per level). Its `EmissiveTint` follows `VaultDoor_DialRing.Color` (Warm Marble shade idle, the opener's hue, Alarm Red).

**Runtime colours.** Every Neon part's idle colour is in `eh_palette.NEON` (and the manifest's `neon`), audited against every clone colour (rule N1, Oklab ≥ 0.15), so a press always changes the colour: plate rings and switch lamps idle in dim Vault Steel shade `#4E5675`, the dial ring in Warm Marble shade `#A8987A`, lamps and fairy lights in Bulb Warm `#F6C0A2`. No loot on `TellerCounter_8x4`'s marble top (display rule).

## When the art changes later

1. Claude rebuilds the art (`python3 tools/blender/build_asset.py --all`, then `python3 tools/blender/kit_docs.py`) and tells you which FBX files changed. Unchanged assets keep their FBX, turntable and gate report byte for byte (a content hash in each gate report), so `git status` shows exactly what to re-import.
2. Import only those files (Step 1), with the same settings, and replace the old Models in `Kit` (same names).
3. Run Steps 4 to 6 again.

Every upload makes new mesh ids. That is fine: the ids are inside `Kit.rbxm`.

## Fallback if S2 fails: build the meshes on the server

_This fallback is now built: it is the automated path above (Model uploads instead of single Mesh uploads, plus a CreateMeshPartAsync rebuild for the collision). The original plan, for reference:_

Use this if the meshes, sizes or collision do not survive `rojo build`. Then we do not use `Kit.rbxm`:

1. Upload each mesh once (Studio import with Upload ON, copy each `MeshId`; or Open Cloud with the **`asset:write`** scope, decision D5). The ids must be owned by the **experience owner**.
2. Claude puts the ids in a data table (`Config.Kit`).
3. At server boot the server builds each piece **once** and caches it in `ServerStorage/Kit`:
   ```lua
   local part = AssetService:CreateMeshPartAsync(Content.fromUri(meshId), {
   	CollisionFidelity = Enum.CollisionFidelity.Box, -- per the table above
   	RenderFidelity = Enum.RenderFidelity.Automatic,
   })
   ```
   Then it sets Size, TextureID, Material, PivotOffset and the other flags from the manifest. Each heist clones the cached parts.
<!-- fallback-cost:start -->
4. Cost: about 22 ms per mesh plus 0.27 ms per 1,000 triangles [UNVERIFIED, DevForum report]: for this kit's 255 MeshParts and 124,466 triangles about **5.6 s** at boot (generated by kit_docs.py). Boot only, never per heist.
<!-- fallback-cost:end -->

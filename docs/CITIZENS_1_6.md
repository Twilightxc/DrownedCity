# Citizens: the survivor build and the leaders (Phase 1.6)

Source: J's spec "1.6รายละเอียดระบบพลเมืองดีเด่น" (2026-11-06), translated. Parts J asked Claude to design are marked
**[Claude proposal]**; J confirms or changes them. Earlier rules (influence, the status ladder, no cap on outstanding
citizens) are in GDD §3 and `docs/PHASE1.md` 1.6.

## 1. One survivor is made of

**core skills + background (add-on special) + community skill + traits + combat class**

All of it is SimCore data (`sim/`, `data/`), saved in the survivor's state (save v2), and unit-tested.

## 2. Leaders

A leader is picked from the outstanding citizens. Each leader type has:
- a special room
- special items, made in tier-4 buildings
- an effect for the whole community
- a goal that unlocks the room and the items

| Leader | Special room | Special items | Effect (community) | Unlock goal |
| --- | --- | --- | --- | --- |
| Warlord (นักรบ) | CQC camp (melee skill XP) · firing range (shooting skill XP) | AP-incendiary-HE rounds: hurt heavy armor and stagger it in one hit (grenade launchers: M79, RPG, underbarrel; snipers, carried and fire support) · special mortar shells (more blast radius and damage) | tighter grouping for every survivor · more damage to all human enemies · more thrown explosives per craft · ammo resources every day | clear every human control point in the city |
| Sheriff (ผู้พิทักษ์) | signal tower, on a roof slot: weather warnings days ahead, horde warnings ahead, buffs base fire support | dragon's breath shells · white-phosphorus mortar shells | a random gun every day · influence bonus for helping survivors | build a radio room for a survivor community, and answer a community's radio call for help (under attack) |
| Builder (นักสร้าง) | large boatyard: big special boats (more crew, more gun mounts, more cargo) | rapid-fire crossbow · mounted harpoon gun | sturdier structures · materials and repair parts every day · storage room upgrade | build a boat for a survivor community |
| Trader (พ่อค้า) | floating market: a large raft-house community on the water | a backpack with many slots | water and food every day, and more output · influence: sell higher, buy lower · more resources farmed from control points · stronger, longer food buffs | make every enclave in the city an ally (trade, exchange, help) |
| Researcher (นักวิจัย) | oil refinery | special buff items · poison-gas mortar shells | fuel, chemicals and medicine every day, and more output | **[Claude proposal]** bring a live infection sample from the flooded hospital lab and research it at the base (an infirmary + lab chain) |
| Programmer (โปรแกรมเมอร์) | weapons lab (weapon upgrades) | flashbang mortar shells · electric mortar shells · drone support | more power, less power use · every turret becomes automatic · auto-production added to rooms · more yield | **[Claude proposal]** restore the city's power control centre (a control point) and link its grid to the base and one enclave |

Open for J:
- GDD §12 also gives each leader a game-ending goal (for example the Warlord destroys every nest). Do those stay, as
  the step after the unlock goal?
- Can a community have more than one leader over a run (a new leader after one dies)?

## 3. Core skills

- Each core skill has levels 0–7, raised by doing (and by base routines).
- At 7, the survivor picks one of four specializations.
- Then the skill climbs 0–7 a second time.
- **[Claude proposal]** In the second climb, the specialization's numbers grow in steps and are full at 7. Until a
  survivor reaches 7 there, they get about half.
- J to confirm.

### Fitness (ฟิตเนส)
Raises HP, stamina, running, swimming, rowing and carrying. Grows from running, rowing, and the fitness corner.

Per level: max stamina —, +3, +6, +9, +12, +15, +18, +21.

| Specialization | Effects |
| --- | --- |
| Acrobatics (จอมปีนป่าย) | +21 max stamina · −50 % climbing stamina · −40 % dodge stamina · dodge farther and faster · less fall damage |
| Backpacking (ป๊ะป๋ากระเป๋าใหญ่) | +61 max stamina · +30 carrying capacity · +60 ammo capacity · +2 grenades · +6 inventory slots · +1 gun slot |
| Marathon (วิ่งสู้ฟัด) | +21 max stamina · −33 % sprint stamina · −40 % fatigue severity · free sprint when lightly loaded · −25 % light-melee stamina |
| Powerhouse (พลังม้าศึก) | +21 max stamina · −25 % melee stamina · execute standing enemies with a heavy weapon (interact from behind) · power hit with a heavy weapon (hold and release attack; staggers heavy enemies) · a heavy hammer breaks walls, doors, windows, bunkers and barricades |

### Melee (ต่อสู้ระยะประชิด)
Raises melee damage, dodging, melee stamina use, and slower wear. Grows from fighting and the punching bag.

Per level: max HP —, +4, +8, +12, +16, +20, +24, +28.

| Specialization | Effects |
| --- | --- |
| Close Combat (มือมีดจอมเชือด) | +28 max HP · knife executions on standing enemies (interact + attack) · −50 % close-combat stamina · better close-combat moves · shove (sprint + attack) |
| Endurance (อดทนดั่งหินผา) | +84 max HP · −50 % injury severity · slam (sprint + attack) |
| Striking (หวือหวาไร้ที่ติ) | +28 max HP · +30 % blunt knockdown · −66 % grand-slam stamina · grand slam hits several enemies (sprint + attack) |
| Swordplay (ฟันไม่เลี้ยง) | +28 max HP · +30 % blade lethality · blade executions on standing enemies (interact + attack) · leg sweep cripples (sprint + attack) |

### Shooting (ยิงปืน)
Raises accuracy, recoil control and reload speed. Grows from shooting, and from standing watch in a tower.

| Per level | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Sway | −3 % | −6 % | −9 % | −12 % | −15 % | −18 % | −25 % |
| Recoil | −3 % | −6 % | −9 % | −12 % | −15 % | −18 % | −25 % |
| Reload speed | +6 % | +12 % | +18 % | +25 % | +30 % | +40 % | +50 % |

| Specialization | Effects |
| --- | --- |
| Assault (จู่โจมระห่ำโลก) | −80 % recoil · +50 % firearm knockdown · −25 % sway · +50 % reload · kick enemies over while aiming |
| Gunslinging (สิงห์ปืนไว) | +200 % reload · cheaper aim snap · −25 % sway · −25 % recoil · snap to targets while aiming |
| Sharpshooting (แม่นเหมือนจับวาง) | −80 % sway · +50 % dismemberment · −25 % recoil · +50 % reload · every bullet pierces |
| Weapon Handling (พริ้วไหวดั่งสายน้ำ) | −25 % wear per shot · clears jams very fast · −25 % sway · −25 % recoil · +50 % reload |

### Wits (ไหวพริบ)
Raises search speed, quiet movement and spotting traps. Grows from searching and reading.

Per level, search speed: —, +5 %, +10 %, +15 %, +20 %, +25 %, +30 %, +35 %. J's sheet says +50 % at level 1, which
looks like a typo for +5 %; J to confirm.

| Specialization | Effects |
| --- | --- |
| Discipline (วินัยเคร่งคัด) | +35 % search · +30 light carrying · −25 % melee wear per hit · +24 max stamina · +5 stamina per melee kill |
| Resourcefulness (ไหวพริบเฉียบแหลม) | +35 % search · +1 inventory slot · +3 stack size · −70 % consumable weight · more crossbow bolts recovered |
| Scouting (สอดแนมตาดี) | +35 % search · +45 m enemy detection · +70 % container visibility · −25 % gun wear per shot · containers revealed in unsecured buildings |
| Stealth (มัจจุราชไร้เงา) | +35 % search · −35 % enemy sight range · −50 % search-noise chance · quick stealth kills (interact) · sprint while crouched · open locked doors silently while crouched |

### Diving (ดำน้ำ)
Raises time underwater, underwater speed, and sight in murky water. Grows from diving.

| Per level | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Breath (s) | +3 | +6 | +9 | +12 | +15 | +18 | +21 |
| Underwater stamina use | −3 % | −6 % | −9 % | −12 % | −15 % | −18 % | −25 % |

**[Claude proposal]** The four specializations, written to match the others:

| Specialization | Effects |
| --- | --- |
| Free Diving (ปลาฉลามมนุษย์) | +21 s breath · +30 % swim speed underwater · −50 % underwater stamina · surface breaths refill twice as fast |
| Salvage (นักกู้ซากใต้น้ำ) | +21 s breath · +50 % search speed underwater · one extra loot roll in flooded floors and sunken vehicles · +20 carrying capacity underwater |
| Murk Sight (ตาเหยี่ยวในน้ำขุ่น) | +21 s breath · +100 % sight in murky water · no helmet light needed near the surface · sunken containers show within 15 m |
| Spearfishing (นักล่าใต้คลื่น) | +21 s breath · +50 % harpoon / underwater gun damage · +50 % harpoon reload · silent underwater kills (interact from behind) · fish for food on the boat |

## 4. Backgrounds (add-on special)

Exactly one per survivor, rolled at birth.

| Background | Effects |
| --- | --- |
| Ex-soldier (อดีตทหาร) | shooting starts at 3 · spread −25 % · throws farther · reloads faster |
| Fisherman (ชาวประมง) | boats use less fuel · boats break less · diving starts at 3 |
| Doctor (หมอ) | gets sick less · heals faster · makes special medicine · wits starts at 3 |
| Teacher (ครู) | base members gain XP faster · wits starts at 3 |
| Programmer (โปรแกรมเมอร์) | less power use · wits starts at 3 |
| Researcher (นักวิจัย) | fewer resources per craft · less fuel use · wits starts at 3 |
| Construction worker (ช่างก่อสร้าง) | fewer building resources · fitness starts at 3 |
| Farmer (เกษตรกร) | less water use · fitness starts at 3 |
| Boxer (นักมวย) | fitness starts at 3 · melee starts at 3 |

This replaces the "Background" row in the GDD §3 trait table (Ex-Soldier, Fisherman, Nurse, Mechanic).

## 5. More traits

These are added to the GDD §3 trait table. The names are **[Claude proposal]**:

| # | Group | Trait | Effect |
| --- | --- | --- | --- |
| 1 | mind & social | Workhorse | works longer shifts |
| 2 | body | Short Sleeper | needs less rest |
| 3 | mind & social | Haggler | sells higher |
| 4 | body | Quick Breather | stamina regenerates faster |
| 5 | body | Robust | recovers from illness faster |
| 6 | body | Resistant | infection is less likely |
| 7 | body | Fast Healer | HP and blood regenerate faster |
| 8 | body | Deep Lungs | more breath underwater |
| 9 | mind & social | Well Liked | influence bonus |

The GDD rule stays: 2–3 traits each, at least one negative.

## 6. Community skills and books **[Claude proposal]**

J asked for this to be designed in the spirit of State of Decay. The rules:
- Each survivor has **one community skill slot**: a trade they bring to the base.
- Some are born with one. A survivor with an empty slot learns one by **reading its book** (a found item; reading
  takes days in the library corner).
- A survivor who already has a skill reads a **specialization book** to add one of its two specializations.
- A community skill unlocks rooms and crafts, and raises a room's output while that survivor works there.
- It also decides which **leader type** the survivor can become (GDD §12: "leader personality from the special skill,
  or from a book").

The list builds on the GDD §3 special-skills list (doctor, mechanic, electrician, farming, chemistry, gunsmith,
tailor, radio, pro diver, fisher, teacher, cook):

| Community skill | Base effect | Specializations (book) | Leader path |
| --- | --- | --- | --- |
| Medicine | infirmary tier 2; injuries heal faster | Surgery (heavy injuries in half the time) · Pathology (antiviral crafting, infection research) | Researcher |
| Chemistry | chemistry bench: fuel, explosives, flamethrower fuel | Explosives (more grenades per craft, mortar shells) · Pharmacy (medicine crafting) | Researcher |
| Computing | electronics bench; less power use | Programming (automation, turret AI) · Networking (link other communities, trade from the radio) | Programmer |
| Electrics | generators and lights; power tier 2 | Solar (power without fuel) · Batteries (store power overnight) | Programmer |
| Engineering | workshop tier 2; build and repair faster | Fortification (stronger barricades and walls) · Plumbing (rainwater and purifier upgrades) | Builder |
| Seamanship | boat dock; boat repair | Shipwright (bigger boats, gun mounts) · Navigation (less fuel, faster routes, storm warnings at sea) | Builder |
| Gunsmithing | armoury; gun repair | Ammo reloading (ammo crafting) · Modding (attachments) | Warlord |
| Combat training | training corner; members level melee and shooting faster | CQC instruction · Marksmanship instruction | Warlord |
| Radio | radio room; contact with other communities and calls for help | Signals (warnings ahead) · Negotiation (influence on deals) | Sheriff |
| Leadership | morale up for everyone · settles fights | Diplomacy (enclave relations) · Discipline (fewer refused jobs at low morale) | Sheriff |
| Gardening | rooftop garden; more food | Hydroponics (food on water, no soil) · Herbalism (herb medicine) | Trader |
| Cooking | kitchen; meals with buffs | Nutrition (longer food buffs) · Preserving (food spoils slower) | Trader |
| Fishing | fish traps from the dock; food from the water | Net fishing (more food) · Bait & lures (rare catches) | Trader |
| Teaching | members learn skills faster | Library (books read in half the time) · Mentoring (pass on one specialization) | any |

Outstanding-citizen buff **[Claude proposal]**, still open from 2026-11-05:
- An outstanding citizen's community skill also works **base-wide at half strength** while they are in the base.
  For example, a Medicine citizen speeds up healing for everyone a little.
- So every outstanding citizen's buff applies at once, leader or not, as J set.

## 7. Combat classes **[Claude proposal]**

A class is the survivor's role in a fight. Each has:
- a weapon it prefers
- one passive
- one active ability on a cooldown, used with the ability key (pad: L3 + R3, or a free button)

A survivor picks a class when they become a **member**. They can change it in a training room (the Warlord's CQC camp
or firing range), which costs a day.

A class gives no stat points of its own. It leans on the core skills (for example, Breacher's passive grows with the
melee skill). Teammates use their class ability on their own, with simple rules in `TeammateBrain`.

| Class | Weapons | Passive | Active (cooldown) |
| --- | --- | --- | --- |
| Rifleman (พลปืนไรเฟิล) | AR, DMR | +10 % damage beyond 15 m | **Steady**: 5 s of no sway, half recoil (40 s) |
| Breacher (หน่วยบุก) | shotgun, melee | −20 % melee damage taken; melee stamina −15 % | **Shove**: a cone knockback that staggers everything within 3 m (25 s) |
| Marksman (พลแม่นปืน) | DMR, sniper | sees and targets 25 % farther in fog | **Mark**: the zombie under the aim and its pack are outlined; the team does +25 % to them for 8 s (45 s) |
| Medic (หน่วยแพทย์) | pistol, SMG | revives 2× faster; bandages heal more | **Field kit**: a 4 m circle heals 30 HP over 6 s and stops bleeding (60 s) |
| Engineer (ช่างสนาม) | SMG, shotgun | repairs barricades and boats 2× faster | **Deploy**: a quick barricade or a noise decoy that draws the horde for 10 s (50 s) |
| Grenadier (พลระเบิด) | grenade launcher, AR | +2 grenades carried; −25 % self-blast damage | **Barrage**: three frags thrown in a fan (60 s) |

The demo needs only the data model plus 3 classes, Rifleman, Breacher and Medic, behind `demo_build`. The others are
data entries for later.

## 8. What 1.6 builds, and what waits for later systems

Many effects need systems that don't exist yet: climbing, inventory slots and stacks, carrying weight, executions,
heavy/blunt/blade weapon types, dismemberment, fall damage, search noise, swimming and diving, boats, human enemies,
control points, enclaves, mortars, drones and power.

1.6 builds the **data model and the rules**:
- every skill, specialization, background, trait, community skill, class and leader as `data/` resources
- modifiers by `stat` / `weapon_class` (`mul` or `add`), as GDD §3 already describes for traits
- XP and levels, specialization choice, books, influence and status, leader choice

An effect lights up when its system arrives; until then it is listed but has no target. 1.6 wires up only the
effects whose systems exist now:
- HP, stamina, sprint and dodge stamina
- sway / recoil / reload / wear / jams
- melee stamina and damage
- search speed (once looting exists), noise and sight ranges
- revive speed

All of it is content-flagged (`demo_build`), not forked.

## 9. Open questions for J

1. What does the second climb 0–7 after a specialization give (§3)? Is the proposal OK?
2. Wits level 1: +5 % or +50 % search speed?
3. The unlock goals for the Researcher and the Programmer (§2): are the proposals OK?
4. Do the GDD §12 end goals stay alongside the unlock goals?
5. Community skills, books and the outstanding-citizen buff (§6): OK as proposed?
6. The combat classes (§7): OK? Which three go in the demo?
7. Diving specializations and the trait names (§3, §5): OK?
8. Can status be lost (open since 2026-11-05)?

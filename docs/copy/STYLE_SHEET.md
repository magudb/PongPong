# Danish dialogue and interface copy

Use these rules for all new town, farm and social copy. Danish is primary; English must carry the same meaning. Text changes stay in localization CSVs. Approved user recordings remain frozen. The numeric limits are checked in tools/copy/font_budget.json. Actual shipped canonical names exceed the original name estimate: Borgmester Hyldeblomst is 252.5 px and Carpenter fairy Hasselnød is 267.25 px at Caprasimo 20. Preserve those approved names and allow 272 px plus padding in the runtime nameplate; its measured budget is 26 characters.

The binding rules below reproduce the integration design, section 4.2. The FIRST slot is the runtime spelling of a first meeting; birthdays use BDAY and gift reactions use GIFT, followed by the citizen or archetype cascade.

## R1

du-form, short sentences, concrete cosy detail; the builder fairy lines are the model ("Bindingsværk er som en god historie: Der skal være noget at holde fast i."). The guide: "Venlig og lun", "Korte knapper" (Køb, Sælg, Lav, Tilbage), "Mørkeskoven hvisker".

Good Danish examples:

- Kom indenfor. Her dufter af træ.
- Du kan plante frøene ved broen.
- Tag en varm bolle med.

Examples to reject:

- Spilleren anmodes om at træde indenfor.
- Optimer din ressourceallokering.
- Der er blevet foretaget en levering.

## R2

Length by slot (measured with the real fonts, designer 5): dialogue page <= 240 characters (3 lines of 87), a spoken line <= 14 words; shop greeting bubble <= 110 characters (42 per line); choice <= 32; citizen name <= 21; button <= 10 (menu row <= 16).

Good Danish examples:

- Køb
- Fortæl om bierne
- Du må gerne hvile her.

Examples to reject:

- Se alle de spændende og vidunderlige ting, jeg sælger i min butik.
- Vil du venligst gå med på en ganske usædvanligt lang byttehandel?
- Acceptér straks den efterfølgende transaktion

## R3

Child-friendly: no alcohol (gløgg is "varm æblemost"), no violence words, no jealousy, rivalry, insults, scolding or shaming; relationships are friendship, shared home and hygge; **eligibility is never gender-gated and no sentence assumes the hero's gender** (the hero has no gender field): partner wording is "din partner" / the stage name; the stage names and ceremony are fixed by Q3 before any `PARTNER_` row exists.

Good Danish examples:

- Din partner venter ved broen.
- Vi kan dele et hjem.
- Det var sødt af dig.

Examples to reject:

- Du er en taber.
- Kun piger må være med.
- Tag et glas øl.

## R4

Display names, never ids and never stale names: Borgmester Hyldeblomst (not Lyra), Bagerfe Rosmarin (not Maja), Butiksfe Kløvermynte; the **three Pips** (Kløvermynte = `merchant_pip`, Postbud Pip the hedgehog, Pippin the mouse, plus `hobbit_pip`) are always written with their display names. Banned strings: `PongPong`, `Lyra` (as a name), `Mjau`, `Eventyrskoven`, `the retired town name`.

Good Danish examples:

- Bagerfe Rosmarin har bagt boller.
- Postbud Pip er på vej.
- Pippin Bøgeknop leder efter sin kat.

Examples to reject:

- Maja har bagt boller.
- Lyra venter.
- merchant_pip sælger frø.

## R5

Voiced lines (`_V`) contain no `%`, no digits, no onomatopoeia (`Hrmf.` made Sara take 2.56 s for 4 words), <= 14 words.

Good Danish examples:

- Tak for gaven. Den luner.
- Du fandt mig!
- Kom, vi ser på stjernerne.

Examples to reject:

- Du fik 12 point.
- Du har %d gaver.
- Hrmf. Grrr.

## R6

No bare `%s` item name inside a sentence (items are indefinite singular without gender data: "Hakke", "Stråhat"): the item goes into the toast ("Du gav Stråhat"), the sentence says "gaven" / "den her".

Good Danish examples:

- Tak for gaven!
- Den her får en fin plads.
- Du gav Stråhat

Examples to reject:

- Jeg glæder mig til at bruge en %s.
- Din %s er en smuk ting.
- Jeg kan bage med denne %s.

## R7

Time and calendar words come from `UI_WEEKDAY_*`, `UI_MONTH_*`, `UI_WEATHER_*`, `TimeManager.date_text`; hours as "Åbent %d-%d", "Åbner kl. %d", "Lukket i dag".

Good Danish examples:

- Åbent %d-%d
- Åbner kl. %d
- Lukket i dag

Examples to reject:

- Åbent til klokken syvogtyve
- Monday i den danske kalender
- Timer står altid i amerikansk format

## R8

Both columns mandatory, same `%` signatures (lint exists); English idiomatic, not literal; the English column carries the whole emotional weight (English is never voiced).

Good Danish examples:

- Du gav %s ↔ You gave %s
- Åbner kl. %d ↔ Opens at %d
- Vi ses! ↔ See you!

Examples to reject:

- Du gav %s ↔ You gave %d
- Vi ses! ↔ [tomt]
- Kom indenfor ↔ Come inside of the within

## R9

One broad line is worth more than three narrow ones: tag only the minority of lines with a day part (designer 5: band-only tags give 0 % immediate repeats at TARGET against 8-12 %).

Good Danish examples:

- SOC_BAKER_MAJA_GREET_H0_1
- SOC_ARCH_GARDENER_GREET_H2_1
- SOC_ANY_GREET_1

Examples to reject:

- Hver eneste hilsen kræver regn og torsdag.
- Alle hilsner kræver vinter og nat.
- Der findes kun én smal hilsen.

## R10

Keys follow the convention `SOC_<NPC>_<SLOT>[_<SEASON>][_<PART>][_H<band>]_<n>` with cascade `SOC_<NPC>_...` -> `SOC_ARCH_<ARCH>_...` -> `SOC_ANY_...`; a voiced row ends `_V`.

Good Danish examples:

- SOC_GARDENER_HOPPE_FIRST_1_V
- SOC_ARCH_ELDER_GIFT_LOVE_1
- SOC_ANY_GREET_1

Examples to reject:

- HOPPE_TEKST
- SOC_UNKNOWN_SOMETHING
- MISC_BIRTHDAY_LINE

## R11

The quiet rules: no ASCII quotes inside Lua text, no `--`, commas quoted in CSV, `\n` allowed.

Good Danish examples:

- Hun sagde »velkommen«.
- "Nøglen, den lille, er din." i CSV
- To afsnit bruger \n.

Examples to reject:

- ASCII-citater uden afgrænsning i Lua
- Et komma deler CSV-feltet uden citater
- To bindestreger inde i en Lua-tekst

## Review states

Draft copy needs a language and tone review. AI reviewed copy has had a separate review against these rules; it may be eligible for a later voice bake. Native reviewed means the user has reviewed it. Only the user may set that state, with a reviewer and date. Voice frozen text changes require matching audio changes. No new voice generation is part of this milestone.

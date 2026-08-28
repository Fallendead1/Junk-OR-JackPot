# CLAUDE.md — Junk or Jackpot

Read this file at the start of every session. Read `BUILD-PHASES.md` before writing any code. `junk-or-jackpot-GDD.md` is the specification and is authoritative.

## What this project is

A Roblox game in Luau. Players dig sealed lumps from a landfill; each lump forces one choice — sell it unopened for a guaranteed price, or pay a fee to open it and find out what it was. Full spec in the GDD.

## Who you're working with

The owner is a beginner-to-intermediate Luau scripter learning the language through this project. He drives a truck six days a week and works on this in short sessions. This shapes how you should work:

- **Explain what you wrote, briefly, in plain terms.** Not a tutorial — one short paragraph per file on what it does and why.
- **Prefer obvious code over clever code.** No metatable tricks, no functional-programming flourishes, no premature abstraction. If there's a boring way and a smart way, write the boring way.
- **Name things fully.** `blindOfferPrice`, not `bop`.
- **Comment the non-obvious lines only.** Don't narrate `local x = 0`.
- **When you finish a phase, say what to test manually and how.** He cannot review your code for correctness. He can only play the game. Give him steps.

## Files he writes, not you

These three carry the design and he needs to own them. Do not write or rewrite them without being asked directly:

- `ReplicatedStorage/Modules/ItemTable.lua`
- `ReplicatedStorage/Modules/GradeTable.lua`
- `ServerScriptService/Services/LumpService.lua` — specifically the grade roll and hint generation

You may scaffold them with structure and comments, point out bugs in them, and write everything that consumes them. If he asks you to write them outright, do it — but say once that these are the files worth owning.

## Hard rules

1. **Never invent a number.** Every constant, weight, price, cost, multiplier, and drop rate is in the GDD. If you need a value that isn't there, stop and ask. Do not estimate, do not "use a reasonable default."
2. **All tunable numbers live in `Config.lua` or a data module.** No magic numbers in gameplay code, ever. If you type a number literal into a service file, you've made a mistake.
3. **Server-authoritative, always.** The client asks; it never tells. Every remote handler validates ownership, affordability, and timing before mutating anything. See GDD §12.3 for the list of calculations that must never touch the client.
4. **`EconomyService` is the only code that changes coins, scrap, or relic shards.** No exceptions, no direct profile writes from other services.
5. **One phase at a time.** Build only what the current phase in `BUILD-PHASES.md` lists. Do not build ahead, do not add "while I'm here" features, do not scaffold future systems. If you think something later is needed now, say so and wait.
6. **Stop and report at the end of every phase.** Do not roll into the next one.
7. **Never break a previous phase.** Before finishing, re-run the regression checklist in `BUILD-PHASES.md` for all completed phases.

## Code conventions

- Services are ModuleScripts under `ServerScriptService/Services/`, each returning a table with an `Init()` function. `Main.server.lua` requires and initialises them in explicit order.
- Data modules under `ReplicatedStorage/Modules/` return plain tables and contain **no logic**.
- Remotes live in `ReplicatedStorage/Remotes/`, created at runtime by `Main.server.lua`, never by hand in the explorer.
- Client scripts end in `.client.lua`, server scripts in `.server.lua`, modules in `.lua`.
- Use `task.wait()` and `task.spawn()`, never `wait()` or `spawn()`.
- Use `ProfileStore` for persistence. Never raw `DataStoreService` in gameplay code.
- Every remote handler starts with a rate-limit check and a validation block before any mutation.

## Testing

You cannot playtest. He can. For every phase, end your work with:

```
## Test this phase
1. <specific action in Studio>
   Expect: <specific observable result>
2. ...

## Try to break it
1. <specific abuse case>
   Expect: <the game refuses / nothing bad happens>
```

Be concrete. "Test the dig system" is useless. "Hold E on the dig spot, release at 1 second, expect no lump to spawn" is useful.

## When you're unsure

Ask. A stopped build is cheap. A build that guessed a drop weight and shipped is expensive, because the economy is cross-checked and one wrong number invalidates the pacing tables in GDD §5.7.

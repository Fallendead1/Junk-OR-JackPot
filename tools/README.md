# Asset pipeline: Rodin → Blender → Roblox Studio

This is the one-time setup for turning an AI-generated model into something
sitting in your Studio place, with as little manual export/import as
Roblox's own tools allow. All of this runs on your PC — it has nothing to
do with the game code phases in `BUILD-PHASES.md`, and none of it touches
`ItemTable.lua`, `GradeTable.lua`, or `LumpService.lua`.

Three pieces, installed once:

1. **The Blender cleanup script** — `tools/blender/fix_for_roblox.py` in this
   repo. Fixes the common AI-mesh problems (un-applied scale, flipped
   normals, floating origin) before anything leaves Blender.
2. **The official Roblox Blender plugin** — sends a model from Blender
   straight into your Roblox account's inventory. No FBX export, no manual
   import.
3. **Studio's built-in MCP server** — lets your local Claude Code session
   see and act on the currently-open Studio place: insert the asset you
   just uploaded, position it, name it, parent it, and run a playtest to
   check it.

## 1. Install the Roblox Blender plugin

- Get it from `github.com/Roblox/roblox-blender-plugin` and install it in
  Blender like any other add-on (Edit > Preferences > Add-ons > Install).
- Open its panel in Blender and click **Log in**. This opens your browser,
  you sign into your Roblox account, and you authorize the plugin. That's
  it — there's no Open Cloud API key to generate or paste in anywhere;
  the plugin handles auth itself once you've logged in.
- Pick the account (or group, if this game is under one) you want uploads
  to go to.

## 2. Enable Studio's MCP server

- In Roblox Studio, open **Assistant** → click the **…** menu → **Manage
  MCP Servers** → turn on **Enable Studio as MCP server**.
- In that same panel, expand **Quick connect** and turn on **Claude Code**.
- Restart your local Claude Code session so it picks up the connection.
  Back in the Studio panel you should see a green connected indicator.

Do this with the place you're actually working on open in Studio — the
MCP server acts on whatever place is currently loaded.

## 3. The actual workflow, once both are installed

1. Generate the model in Rodin, download it, open it in Blender.
2. Run `fix_for_roblox.py` on it (see the comment block at the top of that
   file for the two ways to run it — pasting into Blender's Scripting tab
   is the easier one while you're still learning Blender).
3. In the Roblox Blender plugin panel, select the cleaned object(s) and
   click **Upload**. It shows up in Studio under **Toolbox → Inventory →
   My Packages** within a few seconds.
4. With Studio's MCP server connected, tell your local Claude Code session
   what you want done with it — e.g. "insert the lump model I just
   uploaded and put it under `Workspace.Lumps`." Claude Code can search
   your inventory for it, insert it, and run the Luau to position, name,
   and parent it correctly, then start a playtest so you can look at it
   without leaving the chat.

## Things worth knowing

- **The mesh itself never lives in this git repo.** Rojo syncs scripts and
  the instance tree, not binary mesh data. Once a model is uploaded, only
  its Roblox asset ID matters to your code — that's the kind of value that
  belongs in `ItemTable.lua`, not the mesh file.
- **Scale**: the plugin and Studio's importer both expect you to have
  applied your object's scale/rotation in Blender (step 2 above handles
  this). If something comes in the wrong size anyway, check Blender's
  `Object > Apply > All Transforms` was actually applied to that object.
- **Decimation is manual on purpose.** `fix_for_roblox.py` does not reduce
  polycount automatically — do that by hand with a Decimate modifier so you
  can watch the result, since a blanket setting can wreck an AI-generated
  mesh in ways nobody would catch before it ships.
- **Where things get parented in the game hierarchy** is a design decision,
  not a pipeline one — follow whatever the current build phase or the GDD
  says about how lumps/items are structured before wiring a new model in.

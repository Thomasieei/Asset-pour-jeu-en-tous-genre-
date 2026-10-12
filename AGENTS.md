# Shared 3D bank — instructions for coding assistants

Read README.md and catalog.json before choosing assets. catalog.json lists every real model with its relative path, category, source pack, license, file size, SHA-256 and Godot import verification status. Search names and categories; do not invent paths.

Use packs/<pack>/Models/GLTF format/*.glb where available. Preserve original relative texture dependencies when copying a glTF or OBJ model. Copy the relevant License.txt and SOURCE.json into the target game. CC0 licenses in this bank permit redistribution, but do not assume that new external downloads have the same license.

The bank is a source repository, not a single game. Models have been imported with Godot 4.3; this does not certify mobile FPS, rig compatibility, collisions, gameplay, or animations. Inspect the selected model before using it. Avoid copying all 2,082 models into one mobile game.

Do not delete or rewrite other packs when adding assets. Update catalog.json with exact existing paths and source/license evidence. Keep raw authored assets; never commit the Godot .godot cache.

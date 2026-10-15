# Third-party components

This project uses the standard Godot build and GDScript; the game runtime does not require Godot .NET.

## InkGD

- Source: https://github.com/ephread/inkgd
- Pinned Godot 4 branch commit: fea9098ee18d6cdbe9a5e25f8f0296bcdf0fd96a
- Location: addons/inkgd
- License: MIT, reproduced in addons/inkgd/LICENSE.
- Includes the Ink runtime port, with copyright notices for inkle Ltd., Paul Joannon and Frédéric Maquin.
- Vendored runtime files are unmodified. The upstream editor plugin is not enabled. Our small addons/story_workflow plugin handles compilation; scripts/ink_session.gd owns the ordinary runtime service node.

## inklecate / Ink

- Source: https://github.com/inkle/ink
- Compiler: official Windows release v1.1.1, https://github.com/inkle/ink/releases/tag/v1.1.1
- Location: tools/inklecate
- License: MIT, reproduced in tools/inklecate/LICENSE.txt.
- Windows compiler archive checksum is recorded in tools/dependencies.json.
- A build-time tool only; it is excluded from game exports. Compiled story format 21 is used with the pinned runtime.

Inky is an optional external writing application and is not bundled. Its graphical editor was not tested as part of this delivery; the supplied preview entry was compiled and run using the actual Ink compiler/runtime.

Godot is provided separately by the user. Godot's license is available at https://godotengine.org/license/.

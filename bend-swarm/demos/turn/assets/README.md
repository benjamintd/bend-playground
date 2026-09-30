# TURN Outline

`Rubik-Bold.ttf` is the unmodified source font bundled with LibreOffice.
Copyright and SIL Open Font License 1.1: [OFL.txt](OFL.txt).

`../font.bend` is TURN Outline, a generated uppercase Latin subset derived from
that font, also under the OFL. It contains the game's digits and punctuation,
proportional advance widths, and triangulated curves with preserved counters.
Unknown characters display a question mark. It needs no font library at runtime.

Regenerate with `python3 demos/turn/assets/generate-font.py`; add `--check` to
verify the generated file. The generator uses only the Python standard library,
supports the simple TrueType outlines in this alphabet, and checks filled area
after triangulation. It is an asset build tool, not a general font engine.

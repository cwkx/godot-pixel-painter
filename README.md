# Pixel Art Painter
This is a small pixel-art painter addon for use with the Godot engine. This actually makes it pretty powerful even though its just a sprite editor, e.g. you can work with Godots powerful cutout pipeline to edit bone-based animations directly, something you can't even do with Spine.

![Alt text](/screenshot.png?raw=true "")

### Install
Requires latest version of godot: http://fixnum.org/godot/ Copy addons folder and all its contents to your project, restart Godot, then activate plugin from editor settings.

### Features & Usage
To use, simply select a sprite from editor and you're good to go.

- Paint colors from active palette with hotkeys 0-9
- Press 'P' to get palette from selected sprite
 - To use different palettes, create sprites accordingly and press P on them, palettes are transferable to other sprites.
- Undo/Redo support
- Resize sprites with alignment options with Sprite > Resize.. menu
- Differnt brush sizes
- "Save As.."" and "Load" sprites with menu
 - Ctrl+S on sprite to save it
- Painting supports working on rotated/scaled/offset sprites

### Todo
- Fix editor warnings and test/bugfix
- Draw lines between strokes to prevent blobbing between frames in in fast-moving strokes

### License
MIT (c) Chris G. Willcocks

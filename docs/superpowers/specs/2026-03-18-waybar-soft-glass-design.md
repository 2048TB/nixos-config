# Waybar Soft Glass Design

## Goal

Restyle `waybar` to feel lighter, softer, and more premium while preserving the current module set, module order, click actions, scripts, and overall three-section layout.

## Scope

- Modify `nix/home/configs/waybar/style.css`
- Adjust `nix/home/configs/waybar/config.jsonc` only if spacing metadata needs a small correction
- Preserve all existing `waybar` modules, commands, tooltips, and runtime wiring
- Avoid unrelated refactors, dependency changes, or script changes

## References

- Waybar official styling documentation for CSS-driven customization
- `catppuccin/waybar` for soft layering and restrained color contrast
- `mylinuxforwork/dotfiles` for floating grouped capsules and polished spacing

## Design Decisions

### Visual Direction

- Base the structure on a soft premium bar rather than a dense console bar
- Borrow color temperature and translucency from the current floating glass look
- Keep the bar visually light: thinner borders, softer shadows, slightly higher transparency
- Use the existing theme tokens instead of introducing a new fixed palette

### Layout and Grouping

- Keep the current `modules-left`, `modules-center`, and `modules-right` grouping unchanged
- Preserve the existing floating capsule containers for each group
- Reduce container weight by trimming top margin, vertical padding, border heaviness, and shadow depth
- Keep module bodies visually embedded in the group container instead of turning each module into its own solid card

### Workspace Tags

- Replace the current small circular workspace buttons with compact rounded pills
- Keep `focused`, `occupied`, and `urgent` states functionally unchanged
- Make `focused` use a readable highlighted number instead of hiding the label behind an icon
- Use softer occupied styling so inactive tags still read clearly without competing with the focused tag

### Module Rhythm

- Normalize horizontal spacing so `clock`, `network`, `notification`, and `power` feel aligned as one family
- Keep `launcher`, `notification`, and `power` as the strongest visual anchors on the sides
- Preserve current text and icon content; only adjust padding, weight, and background response
- Maintain the current tray, notification pulse, and state color semantics

### Color and States

- Continue using the theme-provided blue as the main accent
- Keep red/yellow/green reserved for urgent or status-specific semantics
- Slightly reduce saturation and contrast for non-critical modules so the bar reads as one system instead of many unrelated widgets
- Retain a subtle hover response and lightweight transitions without adding new animations

## Constraints

- No module additions or removals
- No changes to `exec`, `exec-if`, `on-click`, `on-click-right`, tooltip text, or script paths
- No changes to River integration or Nix wiring
- No wallpaper-specific or monitor-specific styling logic

## Verification

- Diff-check `nix/home/configs/waybar/config.jsonc` to confirm module lists and click commands remain unchanged unless a minimal spacing tweak is explicitly required
- Review `nix/home/configs/waybar/style.css` selectors to ensure all current module IDs and tag states remain covered
- Run `just flake-check`
- If needed, run a targeted eval/build for the affected Home Manager path
- Report live visual verification as `UNVERIFIED` unless the updated bar is actually reloaded and inspected in session

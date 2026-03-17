# Waybar and Wlogout Density Design

## Goal

Tighten the vertical spacing and overall visual density of `wlogout`, while making `waybar` lighter and more balanced by reducing oversized workspace circles, widening inter-item spacing, and harmonizing module padding and icon scale.

## Scope

- Modify only static style/config files for `wlogout` and `waybar`
- Preserve existing theme, module structure, and Nix wiring
- Avoid broad refactors or dependency changes

## Design Decisions

### Wlogout

- Reduce card height and top/bottom internal spacing
- Move icons and labels closer to the visual center
- Keep horizontal width and six-column action layout intact

### Waybar

- Reduce overall bar height slightly to match lighter visual density
- Shrink `river/tags` circles and increase spacing between them
- Rebalance container/module padding so workspace pills no longer feel crowded or oversized
- Slightly reduce icon/text scale where it improves rhythm without hurting readability

## Constraints

- No monitor-specific logic changes
- No module additions/removals
- No changes to runtime scripts or host metadata

## Verification

- Validate edited JSON config syntax
- Run a high-signal repository check for the affected host/config path where feasible
- If full visual/runtime verification is unavailable in the current shell, report that scope as `UNVERIFIED`

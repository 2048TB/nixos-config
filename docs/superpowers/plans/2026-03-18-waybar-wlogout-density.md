# Waybar and Wlogout Density Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `wlogout` and `waybar` visually lighter and more cohesive by tightening empty vertical space, shrinking oversized workspace circles, and rebalancing spacing across modules.

**Architecture:** Keep the existing UI structure and theme tokens, and only retune spacing, size, and layout constants in the CSS/JSON config files already responsible for these surfaces. Verification relies on config syntax checks and the most relevant repository-level check available in the current environment.

**Tech Stack:** NixOS, Home Manager, Waybar, wlogout, CSS, JSONC

---

## Chunk 1: Spec-Locked Visual Density Pass

### Task 1: Tighten `wlogout` card density

**Files:**
- Modify: `nix/home/configs/wlogout/style.css`

- [ ] **Step 1: Update card size and vertical spacing**
- [ ] **Step 2: Keep icon/label alignment visually centered after shrink**
- [ ] **Step 3: Re-read the CSS block to ensure no unrelated theme changes were introduced**

### Task 2: Rebalance `waybar` layout density

**Files:**
- Modify: `nix/home/configs/waybar/style.css`
- Modify: `nix/home/configs/waybar/config.jsonc`

- [ ] **Step 1: Reduce global bar height and spacing to match the lighter target density**
- [ ] **Step 2: Shrink `river/tags` circles and widen spacing between tags**
- [ ] **Step 3: Retune padding/icon sizing for surrounding modules so the bar reads as one cohesive system**
- [ ] **Step 4: Re-read the edited selectors and config keys to confirm the changes stay within scope**

### Task 3: Verify configuration integrity

**Files:**
- Check: `nix/home/configs/wlogout/style.css`
- Check: `nix/home/configs/waybar/style.css`
- Check: `nix/home/configs/waybar/config.jsonc`

- [ ] **Step 1: Run JSON parse validation for `config.jsonc` using a JSONC-aware command**
- [ ] **Step 2: Run the highest-signal repo check available for the affected config**
- [ ] **Step 3: Record any remaining unverified visual/runtime scope explicitly**

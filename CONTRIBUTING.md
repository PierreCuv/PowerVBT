# Contributing to PowerVBT

This is a private project maintained by a small group of athletes. Here's how we work together.

---

## Branch Rules

- **Never push directly to `main`**
- **Never push directly to `dev`** without testing
- Always create a branch for your work

### Creating a branch

```bash
# Always branch off dev
git checkout dev
git pull origin dev
git checkout -b feature/your-feature-name
```

### Branch naming

| Type | Example |
|------|---------|
| New feature | `feature/rep-detection` |
| Firmware work | `firmware/madgwick-filter` |
| App work | `app/live-velocity-screen` |
| Bug fix | `fix/ble-reconnect-crash` |
| Hardware | `hardware/wiring-diagram-v1` |

---

## Workflow

1. Create your branch from `dev`
2. Do your work, commit regularly
3. Push your branch and open a Pull Request → `dev`
4. At least one other person reviews
5. Merge into `dev`
6. When `dev` is stable and tested on device → merge into `main`

---

## Commit Messages

Keep them short and clear. Use prefixes:

```
feat: add peak velocity calculation
fix: BLE disconnects after 30s
refactor: split imu driver into separate file
docs: add wiring diagram v1
hardware: update BOM with ICM-42688 breakout
```

---

## Adding a Feature

Before starting:
- Check existing issues / discussions to avoid duplicates
- Describe what you're building in a comment or message to the group

---

## Testing on Device

Before merging into `dev`:
- [ ] Firmware compiles without errors
- [ ] Device connects via BLE
- [ ] Rep detection works on at least 3 real sets
- [ ] App receives and displays data correctly
- [ ] No obvious battery drain regression

---

## Questions?

Open an issue or message the group directly.

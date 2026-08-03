---
name: refreshing-visual-baselines
description: Refreshes the visual-regression baselines after an intentional visual change. Use when the snapshot suite reports an intended difference.
---

# Refresh the visual baselines

## Steps

1. Run the snapshot suite in the light theme.
2. Run the snapshot suite in the dark theme (delete the stale diff directory first,
   because a stale diff mixes the old run's images into the new report).
3. Review each reported difference.
4. When every difference is intentional, commit the refreshed baselines.

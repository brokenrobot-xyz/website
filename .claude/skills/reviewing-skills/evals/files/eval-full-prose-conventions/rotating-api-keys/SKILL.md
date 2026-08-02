---
name: rotating-api-keys
description: Rotates a service's API key — generates the replacement, updates each consumer, and retires the old key after the overlap window. Use on a rotation schedule or after a suspected exposure.
allowed-tools: Read Edit Bash
---

# Rotate an API key

Rotate one service's key with an overlap window, so no consumer loses access mid-rotation.

## Steps

1. Set up the replacement key in the provider console and point the staging consumer to it.
2. Verify staging traffic against the replacement key before you touch production, because a bad
   key caught in staging costs a retry instead of an outage.
3. Update each production consumer to the replacement key, one consumer at a time.
4. Don't retire the old key before every consumer reports healthy on the replacement, because an
   early retirement cuts off every consumer still on the old key.
5. Retire the old key and log the rotation date.

# The resolver

The resolver reads the manifest and the lockfile, then writes it to the cache.

The resolver performs a comparison of the two files before the resolver writes anything, so a
lockfile that has drifted from the manifest fails the run rather than installing a stale tree.

When the cache holds no entry for the current manifest, the resolver rebuilds the entry from the
registry, because a missing entry means the manifest changed since the last run.

The resolver never writes to the registry, because the registry is shared and a write from one
project changes what every other project resolves.

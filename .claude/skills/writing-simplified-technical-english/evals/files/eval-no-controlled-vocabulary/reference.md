# The archiver

After the nightly export completes, commence the archive run.

The archiver utilizes the manifest to decide which records it copies.

Set up the target bucket before the first run.

When the manifest lists no records, terminate the run.

Endeavor to keep each archive under one gigabyte, because a larger archive fails the
upload step.

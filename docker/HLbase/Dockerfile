# HLbase — the recipe for the HLDS/Counter-Strike game content, not the content.
#
# FROM scratch: this image contains exactly one file, fetch-content.sh. The runner
# copies that script out and runs it at first start, so each deployer downloads
# Valve's content themselves through steamcmd, under their own Steam Subscriber
# Agreement.
#
# This is deliberate. Baking the content in would mean redistributing Valve's
# copyrighted files (hlds_linux, steamclient.so, the WADs, maps, models, sounds).
# Anonymous steamcmd grants a licence to download and run that content, not to
# redistribute it -- which is why every public HLDS image ships the recipe.
#
# Build (context is this folder, no repo files are needed):
#   podman build -f docker/HLbase/Dockerfile -t hlbase:latest docker/HLbase
#
# The script needs curl, tar and a 32-bit runtime; those live in the runner image
# that executes it, not here. Nothing in this image is runnable on its own.

FROM scratch

COPY fetch-content.sh /hlbase/fetch-content.sh

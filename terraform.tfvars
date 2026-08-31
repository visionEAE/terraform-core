# First-deploy images, by digest (pushed by scripts/deploy.sh). Read only at creation:
# afterwards the pipelines own which build is live.
auth_image    = "us-central1-docker.pkg.dev/project-42179253-bad9-49f0-835/s360-prod-images/s360-auth@sha256:675bba42659cec9d788de7f3f8638e8ab205c0c30d34c62f8f2abb7678b07ffa"
gateway_image = "us-central1-docker.pkg.dev/project-42179253-bad9-49f0-835/s360-prod-images/s360-gateway@sha256:cd6779314763f2bf14507fd1490728a67caf0a9bc033e12c2b8fe8db468a9e26"
core_image    = "us-central1-docker.pkg.dev/project-42179253-bad9-49f0-835/s360-prod-images/s360-core@sha256:6a847275f15356c2839a34e9f7dca3dd2997e134767e49c79434bea3be76119c"
lms_image     = "us-central1-docker.pkg.dev/project-42179253-bad9-49f0-835/s360-prod-images/s360-lms@sha256:1e92991249fdab703eeb5fbcfa9c643b3b3ae40596d937ddb57367bed6afab02"
support_image = "us-central1-docker.pkg.dev/project-42179253-bad9-49f0-835/s360-prod-images/s360-support@sha256:d034afee0a525b874f83ec03909c7fd1b26ab8d3b746bb298e013650f6e92a30"
network_image = "us-central1-docker.pkg.dev/project-42179253-bad9-49f0-835/s360-prod-images/s360-network@sha256:e6dc660d389e0cf79bd4060261968b74481bf2f65298a96b2bc1487efc0df7ff"

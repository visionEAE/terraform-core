# First-deploy images, by digest (pushed by scripts/deploy.sh). Read only at creation:
# afterwards the pipelines own which build is live.
auth_image    = "us-central1-docker.pkg.dev/project-42179253-bad9-49f0-835/s360-prod-images/s360-auth@sha256:3928da19a3f0aef79e8c7d2101f33d45acfdcdb9837fa15a58b7cd748ec37733"
gateway_image = "us-central1-docker.pkg.dev/project-42179253-bad9-49f0-835/s360-prod-images/s360-gateway@sha256:eab757e8537a90eddc16c7bb7cd4626475a045fdab3af33b0cbbc7deabbfb078"
core_image    = "us-central1-docker.pkg.dev/project-42179253-bad9-49f0-835/s360-prod-images/s360-core@sha256:6a847275f15356c2839a34e9f7dca3dd2997e134767e49c79434bea3be76119c"
lms_image     = "us-central1-docker.pkg.dev/project-42179253-bad9-49f0-835/s360-prod-images/s360-lms@sha256:1e92991249fdab703eeb5fbcfa9c643b3b3ae40596d937ddb57367bed6afab02"
support_image = "us-central1-docker.pkg.dev/project-42179253-bad9-49f0-835/s360-prod-images/s360-support@sha256:0a2f824564ea9f1695651d590afd4e64609c77d0094b103d7a8b185e9b3fbf36"
network_image = "us-central1-docker.pkg.dev/project-42179253-bad9-49f0-835/s360-prod-images/s360-network@sha256:5bbe8f2d05f86199e203923dac2d3695f93dbc2f1f75038c15b950e80372539a"

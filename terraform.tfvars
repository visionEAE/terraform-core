# Filled in during the first deployment: the six Java images must exist in Artifact Registry
# before the first apply (scripts/deploy.sh pushes them); web and relay start from the hello
# placeholder and are rolled by their own pipelines afterwards.
auth_image    = "CHANGE-ME"
gateway_image = "CHANGE-ME"
core_image    = "CHANGE-ME"
lms_image     = "CHANGE-ME"
support_image = "CHANGE-ME"
network_image = "CHANGE-ME"

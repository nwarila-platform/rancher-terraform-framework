# All five synthetic providers in this reference framework are configuration-free:
# null, random, local, time, and tls. Source and version pins live in versions.tf;
# no provider blocks are needed.
#
# This is intentional whether the framework is run as the root module by the
# reusable deploy workflow or as a child module by the runner integration tests:
# empty provider blocks add no configuration and make provider inheritance less
# clear.

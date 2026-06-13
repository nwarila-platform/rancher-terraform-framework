# ============================================================================================ #
# providers.tf - Provider handoff for deploy module                                            #
# ============================================================================================ #

# The tenant root configures the helm provider from the scoped deploy credential
# seam and injects it into this module. Step 28 changes that root credential
# source from caller-supplied sensitive input to Vault-brokered TokenRequest.

# ============================================================================================ #
# providers.tf - Provider handoff for envelope module                                          #
# ============================================================================================ #

# The platform root configures rancher2 and kubernetes providers from sensitive
# admin inputs, then injects them into this module. Keeping provider
# configuration out of the child module preserves normal module composition and
# keeps mocked terraform tests provider-neutral.

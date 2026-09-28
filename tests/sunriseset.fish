# @fish-lsp-disable 7001

@echo (sunriseset --version)

@test "sunriseset --help" (
    sunriseset --help >/dev/null
) "$status" = 0

@test "sunriseset sunrise" (
   sunriseset sunrise
) = "07:00"

@test "sunriseset sunset" (
   sunriseset sunset
) = "19:00"

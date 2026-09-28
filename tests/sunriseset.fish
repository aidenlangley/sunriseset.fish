# @fish-lsp-disable 7001

@echo (sunriseset --version)

@test "sunriseset --help" (
    sunriseset --help >/dev/null
) "$status" = 0

@test "sunriseset sunrise with config" (
   sunriseset sunrise
) = "07:00"

@test "sunriseset sunset with config" (
   sunriseset sunset
) = "19:00"

set lat -3.1415
set lng 3.1415

@test "sunriseset sunrise with flags" (
   sunriseset sunrise --lat $lat --lng $lng
) = "07:00"

@test "sunriseset sunset with flags" (
   sunriseset sunset --lat $lat --lng $lng
) = "19:00"

set cache "$XDG_CACHE_HOME/sunriseset"
rm "$cache"
sunriseset >/dev/null

@test "creates cache" -n (
  ls $XDG_CACHE_HOME | grep 'sunriseset'
)

# @test "" () 

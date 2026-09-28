# @fish-lsp-disable 7001

@test "sunriseset --help" (
    sunriseset --help >/dev/null
) $status = 0

set ver (sunriseset --version)

@test "sunriseset --version" (
  sunriseset --version
) = $ver

set sunrise (sunriseset sunrise)
set sunset (sunriseset sunset)

@test "sunriseset sunrise w/ latitude + longitude from config" (
   sunriseset sunrise
) = $sunrise

@test "sunriseset sunset w/ latitude + longitude from config" (
   sunriseset sunset
) = $sunset

# Taking a copy of the cache here - when we run sunriseset with -t/--latitude
# and -g/--longitude, we want to make sure it's not hitting the cache. The
# previous calls will have created a cache entry, so it will always exist.
set cache $XDG_CACHE_HOME/sunriseset
set cached_date (cat $cache)

# Arbitrary latitude and longitude. I like pies.
set lat -3.1415
set lng 3.1415

# Grab the sunrise and sunset to test against.
set sunrise (sunriseset sunrise -t $lat -g $lng)
set sunset (sunriseset sunset -t $lat -g $lng)

@test "sunriseset sunrise w/ latitude + longitude (implies -s/--skipcache)" (
   sunriseset sunrise -t $lat -g $lng
) = $sunrise

@test "sunriseset sunset w/ latitude + longitude (implies -s/--skipcache)" (
   sunriseset sunset -t $lat -g $lng
) = $sunset

# Now we check if the previous calls wrote to the cache file. They shouldn't
# when they have both latitude and longitude. If diff returns 0, they are the
# same.
@test "cache was skipped" (
  echo $cached_date | diff $XDG_CACHE_HOME/sunriseset -
) $status = 0

# We're going to remove the cache here and test that it writes to cache when
# it doesn't exist.
rm $cache

# Call sunriseset and ignore its output. Just grep for cache file in cache dir.
@test "creates cache if not present" -n (
  sunriseset &>/dev/null && ls $XDG_CACHE_HOME | grep 'sunriseset'
)

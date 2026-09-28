function sunriseset --description 'Get sunrise and sunset from api.sunrise-sunset.org'
    set --global __name (string split '.' (basename (status -f)))[1]
    set --global __version '1.0.5'
    set --global __description 'Get sunrise and sunset from api.sunrise-sunset.org'

    set opts (fish_opt --short c --long config --required-val)
    set opts $opts (fish_opt --short g --long longitude --required-val)
    set opts $opts (fish_opt --short h --long help)
    set opts $opts (fish_opt --short s --long skipcache)
    set opts $opts (fish_opt --short t --long latitude --required-val)
    set opts $opts (fish_opt --short v --long version)
    argparse $opts -- $argv

    if set --query _flag_v
        echo $__version
        return
    end

    if set --query _flag_h
        _print_help
        return
    end

    # When we've got both latitude and longitude, it's safe to assume we don't 
    # want to hit the cache. It's also safe to assume we won't be using the 
    # config.
    if set --query _flag_t && set --query _flag_g
        # Set -s/--skipcache to true.
        set _flag_s true
        # And since we have both latitude and longitude, we won't be looking up
        # a config.
    end

    # Check if we have been given -t/--latitude & -g/-longitude.
    if not set --query _flag_t || not set --query _flag_g
        # No latitude or longitude...
        if set --query _flag_c
            # We've been given a path to a config file.
            set config_file $_flag_c
        else
            # Look up our default config file.
            set config_file "$XDG_CONFIG_HOME/sunriseset/config"
        end

        # No config, no latitude/longitude, no go.
        if not test -e $config_file
            _srs_log --level ERR "Config not found ($config_file), need -t/--latitude and -g/--longitude"
            return 1
        end

        set config (cat $config_file)
        set _flag_t $config[1]
        set _flag_g $config[2]

        # If we still don't have latitude, we can't continue.
        if not set --query _flag_t
            _srs_log --level ERR 'Missing -t/--latitude'
            return 1
        end

        # If we still don't have longitude, we can't continue.
        if not set --query _flag_g
            _srs_log --level ERR 'Missing -g/--longitude'
            return 1
        end
    end

    set lat $_flag_t
    set lng $_flag_g

    function _is_number --description 'Check if value is a number'
        string match --quiet --regex '^-?[0-9]+(\.?[0-9]*)?$' -- "$argv"
    end

    # If latitude is not a number/decimal, we can't continue.
    if not _is_number $lat
        _srs_log --level ERR "$lat is not a number/float"
        return 1
    end

    # If longitude is not a number/decimal, we can't continue.
    if not _is_number $lng
        _srs_log --level ERR "$lng is not a number/float"
        return 1
    end

    set cache_file "$XDG_CACHE_HOME/sunriseset"

    # If we've not been asked to -s/--skipcache, we'll check the cache.
    if not set --query _flag_s && test -e $cache_file
        # It's a hit, so read it in.
        set data (cat $cache_file)

        # However, if the cache was written more than a day ago, we'll need
        # fresh data.
        if test (math (date +'%s') - (stat -c '%Y' $cache_file)) -gt 86400
            set data (_fetch $lat $lng)
            echo $data >$cache_file
        end
    else
        # No cache, so we need fresh data.
        set data (_fetch $lat $lng)
        # Only cache it if -s/--skipcache is not set.
        set --query _flag_s || echo $data >$cache_file
    end

    set data (string split ' ' $data)
    set sunrise $data[1]
    set sunset $data[2]

    if argparse --min-args=1 -- $argv &>/dev/null
        switch $argv[1]
            case r rise sunrise
                echo $sunrise
            case s set sunset
                echo $sunset
        end
    else
        echo "$sunrise $sunset"
    end
end

function _print_help
    set TAB '  '
    set FLAG_DELIM ', '
    set FIND_MY_GPS_COORDS 'https://findmycoordinates.com/find-coordinates'
    set DEFAULT_CONFIG "$XDG_CONFIG_HOME/sunriseset/config"

    set name (set_color --bold green)$__name(set_color --reset)
    set desc (set_color --italic)$__description(set_color --reset)
    printf '%s %s - %s.\n' $name $__version $desc

    set name (set_color --bold cyan)$__name(set_color --reset)
    function _desc --argument-names desc
        echo (set_color --dim brwhite)$desc(set_color --reset)
    end
    function _option --argument-names args
        echo (set_color --bold cyan)$args(set_color --reset)
    end

    echo
    printf '%s\n' (set_color --bold green)'Usage:'(set_color --reset)
    printf '  %s %s\n' $name '[OPTIONS] [ARGS]'
    printf '  %s %s\n' $name 'r/rise/sunrise|s/set/sunset'
    printf '    %s\n' (_desc "Get the sunrise or sunset for the co-ordinates from config ($DEFAULT_CONFIG).")
    printf '  %s %s\n' $name '-t/--latitude -3.14 -g/--longitude 3.14'
    printf '    %s\n' (_desc 'Get the sunset and sunrise times for the given co-ordinates.')
    printf '  %s %s\n' $name '-t/--latitude -3.14 -g/--longitude 3.14 r/rise/sunrise'
    printf '    %s\n' (_desc 'Get the sunrise only for the given co-ordinates.')
    printf '  %s %s\n' $name '-t/--latitude -3.14 -g/--longitude 3.14 s/set/sunset'
    printf '    %s\n' (_desc 'Get the sunset only for the given co-ordinates.')

    echo
    printf '%s\n' (set_color --bold green)'Options:'(set_color --reset)
    printf '  %s\n' (_option (string join -- $FLAG_DELIM -t --latitude)' <LATITUDE>')
    printf '    %s\n' "Your latitude. Find yours here: $FIND_MY_GPS_COORDS"
    printf '  %s\n' (_option (string join -- $FLAG_DELIM -g --longitude)' <LONGITUDE>')
    printf '    %s\n' "Your longitude. Find yours here: $FIND_MY_GPS_COORDS"
end

function _fetch --description 'Get sunrise and sunset from API' --argument-names lat lng
    set BASE_URL 'https://api.sunrise-sunset.org/v2'

    set req "$BASE_URL?lat=$lat&lng=$lng"
    set resp (curl -s $req)

    if not command -sq jq
        _srs_log --level ERR "jq package is missing, please install jq. We use \
      it to parse the JSON returned from api.sunrise-sunset.org."
    end

    set data (echo $resp | jq '.sunrise,.sunset' | string replace --all '"' '')

    set sunrise (string sub --start=12 --end=16 $data[1])
    set sunset (string sub --start=12 --end=16 $data[2])

    echo $sunrise $sunset
end

function _srs_log --description 'Log messages (Levels: ERR, INF, WARN, DEBUG, OK, QUESTION)'
    if functions -q log
        log $argv && return
    end

    set opts (fish_opt --short l --long level --required-val)
    set opts $opts (fish_opt --short t --long timestamp)
    argparse $opts -- $argv

    set msg
    if set --query _flag_t
        set msg (set_color -d)(printf '[%s]' (date +'%H:%M:%S.%N'))(set_color --reset)
    end

    set --query _flag_l && set level $_flag_l
    switch $level
        case dbg debug DBG DEBUG
            set msg $msg (set_color -o cyan)DBG(set_color --reset) $argv
        case inf info INF INFO
            set msg $msg (set_color --bold --dim white)INF(set_color --reset) $argv
        case wrn warn WRN WARN
            set msg $msg (set_color -o yellow)WARN(set_color --reset) $argv
        case err error ERR ERROR
            set msg $msg (set_color -o red)ERR(set_color --reset) $argv
        case ok OK
            set msg $msg (set_color -o green)OK(set_color --reset) $argv
        case question QUESTION
            set msg $msg (set_color -o cyan)'???'(set_color --reset) $argv
        case '*'
            set msg $msg $argv
    end

    echo $msg
end

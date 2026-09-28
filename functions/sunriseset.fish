function sunriseset --description 'Get sunrise and sunset from api.sunrise-sunset.org'
    set __name (string split '.' (basename (status -f)))[1]
    set __version '1.0.0'
    set __description 'Get sunrise and sunset from api.sunrise-sunset.org'

    set opts (fish_opt --short h --long help)
    set opts $opts (fish_opt --short t --long latitude --required-val)
    set opts $opts (fish_opt --short g --long longitude --required-val)
    set opts $opts (fish_opt --short v --long version)
    argparse $opts -- $argv

    function _print_version \
        --inherit-variable __name \
        --inherit-variable __version \
        --inherit-variable __description
        set name (set_color --bold green)$__name(set_color --reset)
        set desc (set_color --italic)$__description(set_color --reset)
        echo (printf '%s %s - %s.' $name $__version $desc)
    end

    if set --query _flag_v
        _print_version
        return
    end

    # Print help.
    if set --query _flag_h
        set TAB '  '
        set FLAG_DELIM ', '

        set FIND_MY_GPS_COORDS 'https://findmycoordinates.com/find-coordinates'
        set DEFAULT_CONFIG "$XDG_CONFIG_HOME/sunriseset/config"

        function _usage --inherit-variable __name --argument-names args
            echo (set_color --bold cyan)$__name(set_color --reset) $args
        end

        function _desc --argument-names desc
            echo (set_color --dim brwhite)$desc(set_color --reset)
        end

        function _option --argument-names args
            echo (set_color --bold cyan)$args(set_color --reset)
        end

        _print_version

        echo
        echo (set_color --bold green)'Usage:'(set_color --reset)
        echo $TAB(_usage '[OPTIONS] [ARGS]')
        echo $TAB(_usage 'r/rise/sunrise|s/set/sunset')
        echo $TAB$TAB (_desc "Get the sunrise or sunset for the co-ordinates from config ($DEFAULT_CONFIG).")
        echo $TAB(_usage '-t/--latitude -3.14 -g/--longitude 3.14')
        echo $TAB$TAB (_desc 'Get the sunset and sunrise times for the given co-ordinates.')
        echo $TAB(_usage '-t/--latitude -3.14 -g/--longitude 3.14 r/rise/sunrise')
        echo $TAB$TAB (_desc 'Get the sunrise only for the given co-ordinates.')
        echo $TAB(_usage '-t/--latitude -3.14 -g/--longitude 3.14 s/set/sunset')
        echo $TAB$TAB (_desc 'Get the sunset only for the given co-ordinates.')

        echo
        echo (set_color --bold green)'Options:'(set_color --reset)
        echo $TAB(_option (string join -- $FLAG_DELIM -t --latitude)' <LATITUDE>')
        echo $TAB$TAB"Your latitude. Find yours here: $FIND_MY_GPS_COORDS"
        echo $TAB(_option (string join -- $FLAG_DELIM -g --longitude)' <LONGITUDE>')
        echo $TAB$TAB"Your longitude. Find yours here: $FIND_MY_GPS_COORDS"

        return
    end

    function _log --description 'Log messages (Levels: ERR, INF, WARN, DEBUG, OK, QUESTION)'
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

    # Check if we have been given -t/--latitude & -g/-longitude
    if not set --query _flag_t || not set --query _flag_g

        # No latitude/longitude - check $XDG_CONFIG_HOME.
        set config_file "$XDG_CONFIG_HOME/sunriseset/config"
        if not test -e $config_file

            # No dice, check $HOME for a config file.
            set config_file "$HOME/.sunriseset"
            if not test -e $config_file

                # No config, no go.
                _log --level ERR 'Config not found, need -t/--latitude and -g/--longitude'
                return 1
            end
        end

        set config (cat $config_file)
        set _flag_t $config[1]
        set _flag_g $config[2]

        if not set --query _flag_t
            _log --level ERR 'Missing -t/--latitude'
            return 1
        end

        if not set --query _flag_g
            _log --level ERR 'Missing -g/--longitude'
            return 1
        end
    end

    function _is_number --description 'Check if value is a number'
        if functions -q is_number
            is_number $argv && return
        end
        string match --quiet --regex '^-?[0-9]+(\.?[0-9]*)?$' -- "$argv"
    end

    set lat $_flag_t
    set lng $_flag_g

    if not _is_number $lat
        _log --level ERR "$lat is not a number/float"
        return 1
    end

    if not _is_number $lng
        _log --level ERR "$lng is not a number/float"
        return 1
    end

    function _fetch --description 'Get sunrise and sunset from API' --argument-names lat lng
        set BASE_URL 'https://api.sunrise-sunset.org/v2'

        set req "$BASE_URL?lat=$lat&lng=$lng"
        set resp (curl -s $req)

        set data (echo $resp | jq '.sunrise,.sunset' | string replace --all '"' '')

        set sunrise (string sub --start=12 --end=16 $data[1])
        set sunset (string sub --start=12 --end=16 $data[2])

        echo $sunrise $sunset
    end

    set cache_file "$XDG_CACHE_HOME/sunriseset"

    if test -e $cache_file
        set data (cat $cache_file)

        if test (math (date +'%s') - (stat -c '%Y' $cache_file)) -gt 86400
            # If cache is more than a day old, get fresh data + overwrite the cache.
            set data (_fetch $lat $lng)
            echo $data >$cache_file
        end
    else
        # No cache, we need fresh data, and we can cache it.
        set data (_fetch $lat $lng)
        echo $data >$cache_file
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

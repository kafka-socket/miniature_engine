-module(miniature_engine_channels).

-export([
    register/1,
    by_key/1,
    all/0
]).

-spec register(binary()) -> true.
register(Key) ->
    true = gproc:reg(build_key(Key)).

-spec by_key(binary()) -> [pid()].
by_key(Key) ->
    gproc:lookup_pids(build_key(Key)).

-spec all() -> [pid()].
all() ->
    gproc:select(_SelectContext = {l, p}, _MatchFunction = [{
        {                    %% MatchHead begins
            build_key('$1'), %% Key   -> $1
            '$2',            %% Pid   -> $2
            '$3'             %% Props -> $3
        },                   %% MatchHead ends
        [],                  %% [Guard]
        ['$2']               %% [Result]
    }]).

-spec build_key(binary() | '$1') -> gproc:key().
build_key(Key) ->
    {
        p, %% type = property
        l, %% scope = local
        {channel, Key}
    }.

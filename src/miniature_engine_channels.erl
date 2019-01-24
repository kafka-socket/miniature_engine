-module(miniature_engine_channels).

-export([
    register/1,
    by_key/1,
    all/0
]).

-define(MATCH_HEAD, {{p, l, {channel, '$1'}}, '$2', '$3'}).
-define(MATCH_SPEC, [{?MATCH_HEAD, [], [true]}]).

register(Key) ->
    true = gproc:reg(build_key(Key)).

by_key(Key) ->
    gproc:lookup_pids(build_key(Key)).

all() ->
    gproc:select(_SelectContext = {l, p}, _MatchFunction = [{
        {                    %% MatchHead begins
            build_key('$1'), %% Key -> $1
            '$2',            %% Pid -> $2
            '$3'             %% Props -> $3
        },                   %% MatchHead ends
        [],                  %% [Guard]
        ['$2']               %% [Result]
    }]).

build_key(Key) ->
    {
        p, %% type = property
        l, %% scope = local
        {channel, Key}
    }.

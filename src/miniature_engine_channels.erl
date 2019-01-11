-module(miniature_engine_channels).

-export([
    register/1,
    by_key/1
]).

register(Key) ->
    true = gproc:reg(build_key(Key)).

by_key(Key) ->
    gproc:lookup_pids(build_key(Key)).

build_key(Key) ->
    {
        p, %% type = property
        l, %% scope = local
        {channel, Key}
    }.

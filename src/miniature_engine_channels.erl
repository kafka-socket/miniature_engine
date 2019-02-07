-module(miniature_engine_channels).

-export([
    register/1,
    by_key/1,
    all/0
]).

-define(KEY(Key), {
    p, %% type = property
    l, %% scope = local
    {channel, Key}
}).

-spec register(binary()) -> true.
register(Key) ->
    true = gproc:reg(?KEY(Key)).

-spec by_key(binary()) -> [pid()].
by_key(Key) ->
    gproc:lookup_pids(?KEY(Key)).

-spec all() -> [pid()].
all() ->
    gproc:select(_SelectContext = {l, p}, _MatchFunction = [{
        {               %% MatchHead begins
            ?KEY('$1'), %% Key   -> $1
            '$2',       %% Pid   -> $2
            '$3'        %% Props -> $3
        },              %% MatchHead ends
        [],             %% [Guard]
        ['$2']          %% [Result]
    }]).

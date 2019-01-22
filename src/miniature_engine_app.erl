%%%-------------------------------------------------------------------
%% @doc miniature_engine public API
%% @end
%%%-------------------------------------------------------------------

-module(miniature_engine_app).

-behaviour(application).

-export([
    start/2,
    stop/1
]).

start(_StartType, _StartArgs) ->
    ok = miniature_engine:start(),
    miniature_engine_sup:start_link().

stop(_State) ->
    ok.

%%%-------------------------------------------------------------------
%% @doc miniature_engine public API
%% @end
%%%-------------------------------------------------------------------

-module(miniature_engine_app).

-include_lib("kernel/include/logger.hrl").

-behaviour(application).

-export([
    start/2,
    prep_stop/1,
    stop/1
]).

start(_StartType, _StartArgs) ->
    ok = miniature_engine:start(),
    miniature_engine_sup:start_link().

prep_stop(State) ->
    ok = miniature_engine:stop_gracefully(),
    State.


stop(State) ->
    ?LOG_DEBUG("miniature_engine_app:stop(~p)", [State]),
    ok.

-module(miniature_engine_healthcheck_handler).

-behaviour(cowboy_handler).

-export([
    init/2
]).

init(Request, State) ->
    {ok, cowboy_req:reply(200, Request), State}.

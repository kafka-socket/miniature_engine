%%%-------------------------------------------------------------------
%% @doc miniature_engine top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(miniature_engine_sup).

-export([
    start_link/0
]).

-behaviour(supervisor).

-export([
    init/1
]).

-define(SERVER, ?MODULE).

-define(FLAGS, #{
    strategy  => one_for_all,
    intensity => 5,
    period    => 10
}).

-define(CHILD(I, Type), #{
    id       => I,
    start    => {I, start_link, []},
    restart  => permanent,
    shutdown => 5000,
    type     => Type,
    modules  => [I]
}).

-define(CHILDREN, [
    ?CHILD(miniature_engine_cowboy_sup, supervisor)
]).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    {ok, {?FLAGS, ?CHILDREN}}.

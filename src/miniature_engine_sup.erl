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

-define(FLAGS, #{
    strategy  => one_for_one,
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
    ?CHILD(miniature_engine_subscriber, worker)
]).

-define(SUPERVISOR, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SUPERVISOR}, ?MODULE, []).

init([]) ->
    {ok, {?FLAGS, ?CHILDREN}}.

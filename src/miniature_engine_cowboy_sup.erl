-module(miniature_engine_cowboy_sup).

-export([
    start_link/0
]).

-behaviour(supervisor_bridge).

-export([
    init/1,
    terminate/2
]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor_bridge:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    {ok, Pid} = cowboy:start_clear(http,
        _TransportOpts = [{port, port()}],
        _ProtocolOpts  = #{env => #{dispatch => dispatch()}}
    ),
    {ok, Pid, state()}.

terminate(_Reason, _State) ->
    ok.

%% private
dispatch() ->
    cowboy_router:compile([{'_', [
        {"/ws", miniature_engine_websocket_handler, []}
    ]}]).

%% private
port() ->
    {ok, Port} = application:get_env(port),
    Port.

%% private
state() ->
    {}.

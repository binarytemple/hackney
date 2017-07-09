-module(hackney_integration_tests).
-include_lib("eunit/include/eunit.hrl").
-include("hackney_lib.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

all_tests() ->
  [
   socket_tests()   ].

socket_tests() ->
    case has_unix_socket() of
      true -> [local_socket_request()];
      false ->  []
    end.

http_requests_test_() ->
    {setup,
     fun start/0,
     fun stop/1,
     fun(ok) ->
         {inparallel, all_tests()}
     end}.

start() ->
    {ok, _} = application:ensure_all_started(hackney),
    ok.

stop(ok) -> ok.

local_socket_request() ->
%% Ms = dbg:fun2ms(fun(_) -> true end ),
%%dbg:tracer(),
%%dbg:p(all, c),

Ms = dbg:fun2ms(fun([_]) -> return_trace(); 
               ([_,_]) -> return_trace(); 
               ([_,_,_]) -> return_trace(); 
               ([_,_,_,_]) -> return_trace();
               ([_,_,_,_,_]) -> return_trace() 
            end),

dbg:tracer(),
dbg:p(all, c),
dbg:tp(lists, seq, cx),
dbg:tp(gen_tcp, Ms , cx),
dbg:tp(hackney, Ms, cx), 
dbg:tp(hackney_connect,Ms, cx), 
dbg:tp(hackney_app, get_app_env, cx), 
dbg:tp(hackney_pool, Ms, cx), 
dbg:tp(hackney_local_tcp, Ms, cx), 

lists:seq(1,10),

URL = <<"http+unix://httpbin.sock/get">>,
{ok, StatusCode, _, _} = hackney:request(get, URL, [], <<>>, []),
?_assertEqual(200, StatusCode).

%% Helpers

has_unix_socket() ->
    {ok, Vsn} = application:get_key(kernel, vsn),
    ParsedVsn = version_pad(string:tokens(Vsn, ".")),
    ParsedVsn >= {5, 0, 0}.

version_pad([Major]) ->
    {list_to_integer(Major), 0, 0};
version_pad([Major, Minor]) ->
    {list_to_integer(Major), list_to_integer(Minor), 0};
version_pad([Major, Minor, Patch]) ->
    {list_to_integer(Major), list_to_integer(Minor), list_to_integer(Patch)};
version_pad([Major, Minor, Patch | _]) ->
    {list_to_integer(Major), list_to_integer(Minor), list_to_integer(Patch)}.

receive_response(Ref) ->
    Dict = receive_response(Ref, orddict:new()),
    Keys = orddict:fetch_keys(Dict),
    StatusCode = orddict:fetch(status, Dict),
    {StatusCode, Keys}.

receive_response(Ref, Dict0) ->
    receive
        {hackney_response, Ref, {status, Status, _Reason}} ->
            Dict1 = orddict:store(status, Status, Dict0),
            receive_response(Ref, Dict1);
        {hackney_response, Ref, {headers, Headers}} ->
            Dict1 = orddict:store(headers, Headers, Dict0),
            receive_response(Ref, Dict1);
        {hackney_response, Ref, done} -> Dict0;
        {hackney_response, Ref, Bin} ->
            Dict1 = orddict:append(body, Bin, Dict0),
            receive_response(Ref, Dict1)
    end.

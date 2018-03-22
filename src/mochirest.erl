
%%% -*- coding: utf-8 -*-
%%% %%%-------------------------------------------------------------------
%%% %%% @author J.Daniel Fernandez <jdaniel.fhermida@gmail.com>
%%% %%% @copyright (C) 2018
%%% %%% @doc mochiweb REST API.
%%% %%% @end
%%% %%% -------------------------------------------------------------------
-module(mochirest).
-export([router/2, respond/2, respond/3]).

%% External API

%% @doc Main loop of the web server where it gets the request,
%% process it and send the response.
%% @end
-spec router(Req::term(), Options::list()) -> term().
router(Req, Options) ->
	"/" ++ Path = Req:get(path),
    Method = erlang:list_to_atom(string:to_lower(erlang:atom_to_list(Req:get(method)))),
    BaseDir = proplists:get_value(basedir, Options, "**"),
	try
		case dispatch(Req, controllers(Method, BaseDir), Options) of
			none -> 
				% No request handler found
                DocRoot = proplists:get_value(docroot, Options),
				case filelib:is_file(filename:join([DocRoot, Path])) of
					true -> 
                        Req:serve_file(Path, DocRoot);
					false ->
                        case proplists:get_value(index, Options) of
                            undefined -> 
                                respond(Req, {error, 404});
                            Index ->
                                Req:serve_file(Index, DocRoot)
                        end
				end;
			Response -> 
				Response
		end
	catch
		Type:What ->
			Report = ["web request failed",
					  {path, Path},
					  {type, Type}, {what, What},
					  {trace, erlang:get_stacktrace()}],
			error_logger:error_report(Report),
			respond(Req, {error, 500})
	end.

%% Internal API

%% @private
%% @doc Gets all the controller modules
%% @end
-spec controllers(atom(), list()) -> term().
controllers(Method, BaseDir) ->
    lists:foldl( fun(Elem, Acc) ->
        {module, Module} = code:ensure_loaded(list_to_atom(filename:rootname(filename:basename(Elem)))),
        Attr = Module:module_info(attributes),
        List = proplists:get_all_values(Method, Attr),
        Acc ++ lists:map( fun(E) ->
            case E of
                [{Url, {Fun, _}}] ->
                    {Url, Module, Fun, undefined};
                [{Url, {Fun, _}, Roles}] ->
                    {Url, Module, Fun, Roles};
                [{Url, Mod, {Fun, _}}] ->
                    {Url, Mod, Fun, undefined};
                [{Url, Mod, Fun}] ->
                    {Url, Mod, Fun, undefined};
                [{Url, Mod, {Fun, _}, Roles}] ->
                    {Url, Mod, Fun, Roles};
                [{Url, Mod, Fun, Roles}] ->
                    {Url, Mod, Fun, Roles}
            end
        end, List)
    end, [], filelib:wildcard(BaseDir ++ "/ebin/*.beam")).

%% @private
%% @doc Match a key list with the value list
%% @end
-spec match_params(list(), list()) -> list().
match_params(Keys, MatchList) ->
    match_params(Keys, MatchList, []).
%% @hidden
match_params([], _, Acc) -> Acc;
match_params(_, [], Acc) -> Acc;
match_params([HK | TK], [HM | TM], Acc) ->
    match_params(TK, TM, [{HK, HM} |Acc]).

%% @private
%% @doc Match a key list with the value list
%% @end
-spec regex(list(), list()) -> {match, list()} | error.
regex(Path, Url) ->
    Split = string:tokens(Url, "/"),
    {Regex, Keys} = lists:foldl( fun(Elem, {Acc, ListAcc}) ->
        case Elem of
            ":" ++ Key ->
                {Acc ++ "/([^/]*)", ListAcc ++ [erlang:list_to_atom(Key)]};
            _ ->
                {Acc ++ "/" ++ Elem, ListAcc}
        end
    end, {"", []}, Split),
    NewRegex = "^" ++ Regex ++ "/?$",
    case re:run(Path, NewRegex, [global, {capture, all_but_first, list}]) of
        {match, [MatchList]} ->
            {match, match_params(Keys, MatchList)};
        _ -> error
    end.

%% @private
%% @doc  Iterate recursively on our list of {Module, Url} tuples
%% to match the URL with de Function it belongs to.
%% @end
-spec dispatch(Req::term(), [tuple()], list()) -> term().
dispatch(_, [], _) -> none;
dispatch(Req, [{Url, Module, Function, Roles} | T], Options) -> 
	Path = Req:get(path),
    AuthFun = proplists:get_value(auth, Options),
	case regex(Path, Url) of
		{match, Param} -> 
			case Roles of
				undefined ->
                    Result = Module:Function(Req, Param),
                    respond(Req, Result);
				Roles ->
					case AuthFun(Req, Roles) of
						{ok, Session} ->
							Result = Module:Function(Req, Session, Param),
                            respond(Req, Result);
						Error ->
							respond(Req, Error)
					end
			end;
		_ -> 
			dispatch(Req, T, Options)
	end.


%% @doc Function to wrap the result of the api.
%% @end
-spec respond(Req::term(), term()) -> term().
respond(_Req, {mochiweb_response, _} = Response) ->
    Response;
respond(Req, {error, 400}) ->
    respond(Req, 400, [{status, 400}, {message, <<"bad request">>}]);
respond(Req, {error, 401}) ->
    respond(Req, 401, [{status, 401}, {message, <<"unauthorized">>}]);
respond(Req, {error, 403}) ->
    respond(Req, 403, [{status, 403}, {message, <<"forbidden">>}]);
respond(Req, {error, 404}) ->
    respond(Req, 404, [{status, 404}, {message, <<"not found">>}]);
respond(Req, {error, 408}) ->
    respond(Req, 408, [{status, 408}, {message, <<"request timeout">>}]);
respond(Req, {error, 409}) ->
    respond(Req, 409, [{status, 409}, {message, <<"conflict">>}]);
respond(Req, {error, 500}) ->
    respond(Req, 500, [{status, 500}, {message, <<"internal error">>}]);
respond(Req, {error, Error}) ->
    Status = proplists:get_value(status, Error, 500),
    respond(Req, Status, Error);
respond(Req, ok) ->
    respond(Req, 200, [{status, 200}, {message, <<"ok">>}]);
respond(Req, created) ->
    respond(Req, 201, [{status, 201}, {message, <<"created">>}]);
respond(Req, {Status, Result}) ->
    respond(Req, Status, Result);
respond(Req, Result) ->
    respond(Req, 200, Result).

%% @doc Function to wrap the result of the api.
%% @end
-spec respond(Req::term(), Status::number(), term()) -> term().
respond(Req, Status, Result) ->
	Req:respond({Status,[{"Content-Type", "json"}],mochijson2:encode(Result)}).

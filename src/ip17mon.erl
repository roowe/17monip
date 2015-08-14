%% https://www.ipip.net/download.html
%% IP17MON的Erlang解析实现
%% 生产环境使用的话，建议使用ets缓存下IPIndex, IPData(减少文件io)，以及查询过的IP（减少再次遍历二进制）
-module(ip17mon).

-export([init/1, find/3]).

-export([test/1]).

test(IP) ->
    {IPIndex, IPData} = init("priv/17monipdb.dat"),
    io:format("~ts~n", [find(IPIndex, IPData, IP)]).

init(DataFile) ->
    {ok, Binary} = file:read_file(DataFile),
    <<Offset0:32/integer, Rest/binary>> = Binary,
    Offset = Offset0 - 4 - 1024,
    <<IPIndex:Offset/binary, IPData/binary>> = Rest,
    {IPIndex, IPData}.

%% 二进制结构
%% Offset:32,0-255Index:1024,IndexData:(Offset-4-1024*2)8个字节,IPData:_
find(IPIndex, IPData, IP) -> 
    {ok, IPAddr} = inet:parse_ipv4_address(IP),
    case find2(IPIndex, IPAddr) of
        fail ->
            "";
        {ok, IPDataOffset, IPDataLength}  ->
            <<_:IPDataOffset/binary, Ret:IPDataLength/binary, _/binary>> = IPData,
            Ret
    end.

find2(<<FirstIndex:1024/binary, SecondIndex/binary>>, {IFirst, _, _, _}=IPAddr) ->
    FirstIndexOffset = IFirst*4, 
    <<_:FirstIndexOffset/binary, Start:32/little, _/binary>> = FirstIndex, %% 一级索引存储的是32bit整数
    IPIndexOffset = 8*Start,
    <<_:IPIndexOffset/binary, RestIPIndex/binary>> = SecondIndex, %% 二级索引存储的是32bit的IP，24bit的IPDataOffset，8bit的IP信息
    find3(RestIPIndex, IPAddr).

find3(<<>>, _) ->
    fail;
find3(<<IP1, IP2, IP3, IP4, IPDataOffset:24/little, IPDataLength, Rest/binary>>, IPAddr) ->
    if 
        {IP1,IP2, IP3, IP4} >= IPAddr ->
            {ok, IPDataOffset, IPDataLength};
        true ->
            find3(Rest, IPAddr)
    end.


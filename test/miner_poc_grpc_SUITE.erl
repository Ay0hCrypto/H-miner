-module(miner_poc_grpc_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("blockchain/include/blockchain_vars.hrl").
-include_lib("blockchain/include/blockchain.hrl").

-export([
    all/0
]).

-export([
    init_per_testcase/2,
    end_per_testcase/2,
    poc_grpc_dist_v11_test/1,
    poc_dist_v11_cn_test/1,
    poc_dist_v11_partitioned_test/1,
    poc_dist_v11_partitioned_lying_test/1
]).

-define(SFLOCS, [631210968910285823, 631210968909003263, 631210968912894463, 631210968907949567]).
-define(NYLOCS, [631243922668565503, 631243922671147007, 631243922895615999, 631243922665907711]).
-define(AUSTINLOCS1, [631781084745290239, 631781089167934463, 631781054839691775, 631781050465723903]).
-define(AUSTINLOCS2, [631781452049762303, 631781453390764543, 631781452924144639, 631781452838965759]).
-define(LALOCS, [631236297173835263, 631236292179769855, 631236329165333503, 631236328049271807]).
-define(CNLOCS1, [
                 631649369216118271, %% spare-tortilla-raccoon
                 631649369235022335, %% kind-tangerine-octopus
                 631649369177018879, %% damp-hemp-pangolin
                 631649369175419391  %% fierce-lipstick-poodle
                 ]).

-define(CNLOCS2, [
                 631649369213830655, %% raspy-parchment-pike
                 631649369205533183, %% fresh-gingham-porpoise
                 631649369207629311, %% innocent-irish-pheasant
                 631649368709059071  %% glorious-eggshell-finch
                ]).

%%--------------------------------------------------------------------
%% COMMON TEST CALLBACK FUNCTIONS
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% @public
%% @doc
%%   Running tests for this suite
%% @end
%%--------------------------------------------------------------------
all() ->
    [
     poc_grpc_dist_v11_test,
     poc_dist_v11_cn_test,
     poc_dist_v11_partitioned_test,
     poc_dist_v11_partitioned_lying_test
     ].

init_per_testcase(poc_grpc_dist_v11_test = TestCase, Config) ->
    miner_ct_utils:init_per_testcase(?MODULE, TestCase, [
        {split_miners_vals_and_gateways, true},
        {num_validators, 8},
        {poc_version, 11},
        {poc_transport, grpc} | Config]);
init_per_testcase(TestCase, Config) ->
    miner_ct_utils:init_per_testcase(?MODULE, TestCase, [
        {split_miners_vals_and_gateways, false},
        {num_validators, 0},
        {poc_transport, grpc} | Config]).

end_per_testcase(TestCase, Config) ->
    gen_server:stop(miner_fake_radio_backplane),
    miner_ct_utils:end_per_testcase(TestCase, Config).

%%--------------------------------------------------------------------
%% TEST CASES
%%--------------------------------------------------------------------
poc_grpc_dist_v11_test(Config) ->
    CommonPOCVars = common_poc_vars(Config),
    ExtraVars = extra_vars(poc_v11),
    run_dist_with_params(poc_grpc_dist_v11_test, Config, maps:merge(CommonPOCVars, ExtraVars)).

poc_dist_v11_cn_test(Config) ->
    CommonPOCVars = common_poc_vars(Config),
    ExtraVars = extra_vars(poc_v11),
    run_dist_with_params(poc_dist_v11_cn_test, Config, maps:merge(CommonPOCVars, ExtraVars)).

poc_dist_v11_partitioned_test(Config) ->
    CommonPOCVars = common_poc_vars(Config),
    ExtraVars = extra_vars(poc_v11),
    run_dist_with_params(poc_dist_v11_partitioned_test, Config, maps:merge(CommonPOCVars, ExtraVars)).

poc_dist_v11_partitioned_lying_test(Config) ->
    CommonPOCVars = common_poc_vars(Config),
    ExtraVars = extra_vars(poc_v11),
    run_dist_with_params(poc_dist_v11_partitioned_lying_test, Config, maps:merge(CommonPOCVars, ExtraVars)).

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

run_dist_with_params(TestCase, Config, VarMap) ->
    run_dist_with_params(TestCase, Config, VarMap, true).

run_dist_with_params(TestCase, Config, VarMap, Status) ->
    ok = setup_dist_test(TestCase, Config, VarMap, Status),
    %% Execute the test
    ok = exec_dist_test(TestCase, Config, VarMap, Status),
    %% show the final receipt counter
    Validators = ?config(validators, Config),
    FinalReceiptMap = challenger_receipts_map(find_receipts(Validators)),
    ct:pal("FinalReceiptMap: ~p", [FinalReceiptMap]),
    ct:pal("FinalReceiptCounter: ~p", [receipt_counter(FinalReceiptMap)]),
    %% The test endeth here
    ok.

exec_dist_test(poc_dist_v11_partitioned_lying_test, Config, VarMap, _Status) ->
    do_common_partition_lying_checks(poc_dist_v11_partitioned_lying_test, Config, VarMap);
exec_dist_test(poc_dist_v10_partitioned_lying_test, Config, VarMap, _Status) ->
    do_common_partition_lying_checks(poc_dist_v10_partitioned_lying_test, Config, VarMap);
exec_dist_test(poc_dist_v8_partitioned_lying_test, Config, VarMap, _Status) ->
    do_common_partition_lying_checks(poc_dist_v8_partitioned_lying_test, Config, VarMap);
exec_dist_test(poc_dist_v7_partitioned_lying_test, Config, VarMap, _Status) ->
    do_common_partition_lying_checks(poc_dist_v7_partitioned_lying_test, Config, VarMap);
exec_dist_test(poc_dist_v6_partitioned_lying_test, Config, VarMap, _Status) ->
    do_common_partition_lying_checks(poc_dist_v6_partitioned_lying_test, Config, VarMap);
exec_dist_test(poc_dist_v5_partitioned_lying_test, Config, VarMap, _Status) ->
    do_common_partition_lying_checks(poc_dist_v5_partitioned_lying_test, Config, VarMap);
exec_dist_test(poc_dist_v11_partitioned_test, Config, VarMap, _Status) ->
    do_common_partition_checks(poc_dist_v11_partitioned_test, Config, VarMap);
exec_dist_test(TestCase, Config, VarMap, Status) ->
    Validators = ?config(validators, Config),
    %% Print scores before we begin the test
    InitialScores = gateway_scores(Config),
    ct:pal("InitialScores: ~p", [InitialScores]),
    %% check that every miner has issued a challenge
    case Status of
        %% expect failure and exit
        false ->
            ?assert(check_validators_are_creating_poc_keys(Validators));
        true ->
            ?assert(check_validators_are_creating_poc_keys(Validators)),
            %% Check that the receipts are growing
            case maps:get(?poc_version, VarMap, 1) of
                V when V >= 10 ->
                    %% There are no paths in v11 or v10 for that matter, so we'll consolidate
                    %% the checks for both poc-v10 and poc-v11 here
                    true = miner_ct_utils:wait_until(
                             fun() ->
                                     %% Check if we have some receipts
                                     C2 = maps:size(challenger_receipts_map(find_receipts(Validators))) > 0,
                                     %% Check there are some poc rewards
                                     RewardsMD = get_rewards_md(Config),
                                     ct:pal("RewardsMD: ~p", [RewardsMD]),
                                     C3 = check_non_empty_poc_rewards(take_poc_challengee_and_witness_rewards(RewardsMD)),
                                     ct:pal("C2: ~p, C3: ~p", [C2, C3]),
                                     C2 andalso C3
                             end,
                             12, 6000),
                    FinalRewards = get_rewards(Config),
                    ct:pal("FinalRewards: ~p", [FinalRewards]),
                    ok;
                _ ->
                    ok
            end
    end,
    ok.

setup_dist_test(TestCase, Config, VarMap, Status) ->
    AllMiners = ?config(miners, Config),
    Validators = ?config(validators, Config),
    GatewayPorts = ?config(gateway_ports, Config),
    {_, Locations} = lists:unzip(initialize_chain(Validators, TestCase, Config, VarMap)),
%%    GenesisBlock = miner_ct_utils:get_genesis_block(Gateways, Config),
    RadioPorts = [ P || {_Miner, {_TP, P, _JRPCP}} <- GatewayPorts ],
    {ok, _FakeRadioPid} = miner_fake_radio_backplane:start_link(maps:get(?poc_version, VarMap), 45000,
                                                                lists:zip(RadioPorts, Locations), Status),
%%    ok = miner_ct_utils:load_genesis_block(GenesisBlock, Validators, Config),
    miner_fake_radio_backplane ! go,
    %% wait till height 2
    ok = miner_ct_utils:wait_for_gte(height, Validators, 2, all, 30),
    ok.

gen_locations(poc_dist_v11_partitioned_lying_test, _, _) ->
    {?AUSTINLOCS1 ++ ?LALOCS, lists:duplicate(4, hd(?AUSTINLOCS1)) ++ lists:duplicate(4, hd(?LALOCS))};
gen_locations(poc_dist_v11_partitioned_test, _, _) ->
    %% These are taken from the ledger
    {?AUSTINLOCS1 ++ ?LALOCS, ?AUSTINLOCS1 ++ ?LALOCS};
gen_locations(poc_dist_v11_cn_test, _, _) ->
    %% Actual locations are the same as the claimed locations for the dist test
    {?CNLOCS1 ++ ?CNLOCS2, ?CNLOCS1 ++ ?CNLOCS2};
%%gen_locations(poc_dist_v11_test, _, _) ->
%%    %% Actual locations are the same as the claimed locations for the dist test
%%    {?AUSTINLOCS1 ++ ?AUSTINLOCS2, ?AUSTINLOCS1 ++ ?AUSTINLOCS2};
gen_locations(_TestCase, Addresses, VarMap) ->
    LocationJitter = case maps:get(?poc_version, VarMap, 1) of
                         V when V > 3 ->
                             100;
                         _ ->
                             1000000
                     end,

    Locs = lists:foldl(
             fun(I, Acc) ->
                     [h3:from_geo({37.780586, -122.469470 + I/LocationJitter}, 13)|Acc]
             end,
             [],
             lists:seq(1, length(Addresses))
            ),
    {Locs, Locs}.

initialize_chain(_AllMiners, TestCase, Config, VarMap) ->
    AllAddresses = ?config(addresses, Config),
    Validators = ?config(validators, Config),
    ValidatorAddrs = ?config(validator_addrs, Config),
    GatewayAddrs = ?config(gateway_addrs, Config),

    N = ?config(num_consensus_members, Config),
    Curve = ?config(dkg_curve, Config),
    Keys = libp2p_crypto:generate_keys(ecc_compact),
    InitialVars = miner_ct_utils:make_vars(Keys, VarMap),
    InitialPaymentTransactions = [blockchain_txn_coinbase_v1:new(Addr, 5000) || Addr <- AllAddresses],
    AddValTxns = [blockchain_txn_gen_validator_v1:new(Addr, Addr, ?bones(10000)) || Addr <- ValidatorAddrs],

    {ActualLocations, ClaimedLocations} = gen_locations(TestCase, GatewayAddrs, VarMap),
    AddressesWithLocations = lists:zip(GatewayAddrs, ActualLocations),
    AddressesWithClaimedLocations = lists:zip(GatewayAddrs, ClaimedLocations),
    InitialGenGatewayTxns = [blockchain_txn_gen_gateway_v1:new(Addr, Addr, Loc, 0) || {Addr, Loc} <- AddressesWithLocations],
    InitialTransactions = InitialVars ++ InitialPaymentTransactions ++ AddValTxns ++ InitialGenGatewayTxns,
    {ok, DKGCompletedNodes} = miner_ct_utils:initial_dkg(Validators, InitialTransactions, ValidatorAddrs, N, Curve),

    %% integrate genesis block
    _GenesisLoadResults = miner_ct_utils:integrate_genesis_block(hd(DKGCompletedNodes), Validators -- DKGCompletedNodes),
    AddressesWithClaimedLocations.


find_receipts(Validators) ->
    [V | _] = Validators,
    Chain = ct_rpc:call(V, blockchain_worker, blockchain, []),
    Blocks = ct_rpc:call(V, blockchain, blocks, [Chain]),
    lists:flatten(lists:foldl(fun({_Hash, Block}, Acc) ->
                                      Txns = blockchain_block:transactions(Block),
                                      Height = blockchain_block:height(Block),
                                      Receipts = lists:filter(fun(T) ->
                                                                      blockchain_txn:type(T) == blockchain_txn_poc_receipts_v2
                                                              end,
                                                              Txns),
                                      TaggedReceipts = lists:map(fun(R) ->
                                                                         {Height, R}
                                                                 end,
                                                                 Receipts),
                                      TaggedReceipts ++ Acc
                              end,
                              [],
                              maps:to_list(Blocks))).

challenger_receipts_map(Receipts) ->
    ReceiptMap = lists:foldl(
                   fun({_Height, Receipt}=R, Acc) ->
                           {ok, Challenger} = erl_angry_purple_tiger:animal_name(libp2p_crypto:bin_to_b58(blockchain_txn_poc_receipts_v2:challenger(Receipt))),
                           case maps:get(Challenger, Acc, undefined) of
                               undefined ->
                                   maps:put(Challenger, [R], Acc);
                               List ->
                                   maps:put(Challenger, lists:keysort(1, [R | List]), Acc)
                           end
                   end,
                   #{},
                   Receipts),

    ct:pal("ReceiptMap: ~p", [ReceiptMap]),

    ReceiptMap.

check_validators_are_creating_poc_keys([Val |_] = _Validators) ->
    Chain = ct_rpc:call(Val, blockchain_worker, blockchain, []),
    Ledger = ct_rpc:call(Val, blockchain, ledger, [Chain]),
    {ok, CurHeight} = ct_rpc:call(Val, blockchain_ledger_v1, current_height, [Ledger]),
    {ok, Block} = ct_rpc:call(Val, blockchain_ledger_v1, get_block, [CurHeight, Ledger]),
    case blockchain_block_v1:poc_keys(Block) of
        [] -> false;
        [_] -> true
    end.

check_eventual_path_growth(TestCase, Miners) ->
    ReceiptMap = challenger_receipts_map(find_receipts(Miners)),
    ct:pal("ReceiptMap: ~p", [ReceiptMap]),
    check_growing_paths(TestCase, ReceiptMap, active_gateways(Miners), false).

check_partitioned_path_growth(_TestCase, Miners) ->
    ReceiptMap = challenger_receipts_map(find_receipts(Miners)),
    ct:pal("ReceiptMap: ~p", [ReceiptMap]),
    check_subsequent_path_growth(ReceiptMap).

check_partitioned_lying_path_growth(_TestCase, Miners) ->
    ReceiptMap = challenger_receipts_map(find_receipts(Miners)),
    ct:pal("ReceiptMap: ~p", [ReceiptMap]),
    not check_subsequent_path_growth(ReceiptMap).

check_growing_paths(TestCase, ReceiptMap, ActiveGateways, PartitionFlag) ->
    Results = lists:foldl(fun({_Challenger, TaggedReceipts}, Acc) ->
                                  [{_, FirstReceipt} | Rest] = TaggedReceipts,
                                  %% It's possible that the first receipt itself has multiple elements path, I think
                                  RemainingGrowthCond = case PartitionFlag of
                                                            true ->
                                                                check_remaining_partitioned_grow(TestCase, Rest, ActiveGateways);
                                                            false ->
                                                                check_remaining_grow(Rest)
                                                        end,
                                  Res = length(blockchain_txn_poc_receipts_v2:path(FirstReceipt)) >= 1 andalso RemainingGrowthCond,
                                  [Res | Acc]
                          end,
                          [],
                          maps:to_list(ReceiptMap)),
    lists:all(fun(R) -> R == true end, Results) andalso maps:size(ReceiptMap) == maps:size(ActiveGateways).

check_remaining_grow([]) ->
    false;
check_remaining_grow(TaggedReceipts) ->
    Res = lists:map(fun({_, Receipt}) ->
                            length(blockchain_txn_poc_receipts_v2:path(Receipt)) > 1
                    end,
                    TaggedReceipts),
    %% It's possible that even some of the remaining receipts have single path
    %% but there should eventually be some which have multi element paths
    lists:any(fun(R) -> R == true end, Res).

check_remaining_partitioned_grow(_TestCase, [], _ActiveGateways) ->
    false;
check_remaining_partitioned_grow(TestCase, TaggedReceipts, ActiveGateways) ->
    Res = lists:map(fun({_, Receipt}) ->
                            Path = blockchain_txn_poc_receipts_v2:path(Receipt),
                            PathLength = length(Path),
                            ct:pal("PathLength: ~p", [PathLength]),
                            PathLength > 1 andalso PathLength =< 4 andalso check_partitions(TestCase, Path, ActiveGateways)
                    end,
                    TaggedReceipts),
    ct:pal("Res: ~p", [Res]),
    %% It's possible that even some of the remaining receipts have single path
    %% but there should eventually be some which have multi element paths
    lists:any(fun(R) -> R == true end, Res).

check_partitions(TestCase, Path, ActiveGateways) ->
    PathLocs = sets:from_list(lists:foldl(fun(Element, Acc) ->
                                                  Challengee = blockchain_poc_path_element_v1:challengee(Element),
                                                  ChallengeeGw = maps:get(Challengee, ActiveGateways),
                                                  ChallengeeLoc = blockchain_ledger_gateway_v2:location(ChallengeeGw),
                                                  [ChallengeeLoc | Acc]
                                          end,
                                          [],
                                          Path)),
    {LocSet1, LocSet2} = location_sets(TestCase),
    case sets:is_subset(PathLocs, LocSet1) of
        true ->
            %% Path is in LocSet1, check that it's not in LocSet2
            sets:is_disjoint(PathLocs, LocSet2);
        false ->
            %% Path is not in LocSet1, check that it's only in LocSet2
            sets:is_subset(PathLocs, LocSet2) andalso sets:is_disjoint(PathLocs, LocSet1)
    end.


check_atleast_k_receipts(Miners, K) ->
    ReceiptMap = challenger_receipts_map(find_receipts(Miners)),
    TotalReceipts = lists:foldl(fun(ReceiptList, Acc) ->
                                        length(ReceiptList) + Acc
                                end,
                                0,
                                maps:values(ReceiptMap)),
    ct:pal("TotalReceipts: ~p", [TotalReceipts]),
    TotalReceipts >= K.

receipt_counter(ReceiptMap) ->
    lists:foldl(fun({Name, ReceiptList}, Acc) ->
                        Counts = lists:map(fun({Height, ReceiptTxn}) ->
                                                   {Height, length(blockchain_txn_poc_receipts_v2:path(ReceiptTxn))}
                                           end,
                                           ReceiptList),
                        maps:put(Name, Counts, Acc)
                end,
                #{},
                maps:to_list(ReceiptMap)).

active_gateways([Miner | _]=_Miners) ->
    %% Get active gateways to get the locations
    Chain = ct_rpc:call(Miner, blockchain_worker, blockchain, []),
    Ledger = ct_rpc:call(Miner, blockchain, ledger, [Chain]),
    ct_rpc:call(Miner, blockchain_ledger_v1, active_gateways, [Ledger]).

gateway_scores(Config) ->
    [V | _] = ?config(validators, Config),
    Addresses = ?config(gateway_addrs, Config),
    Chain = ct_rpc:call(V, blockchain_worker, blockchain, []),
    Ledger = ct_rpc:call(V, blockchain, ledger, [Chain]),
    lists:foldl(fun(Address, Acc) ->
                        {ok, S} = ct_rpc:call(V, blockchain_ledger_v1, gateway_score, [Address, Ledger]),
                        {ok, Name} = erl_angry_purple_tiger:animal_name(libp2p_crypto:bin_to_b58(Address)),
                        maps:put(Name, S, Acc)
                end,
                #{},
                Addresses).

common_poc_vars(Config) ->
    N = ?config(num_consensus_members, Config),
    BlockTime = ?config(block_time, Config),
    Interval = ?config(election_interval, Config),
    BatchSize = ?config(batch_size, Config),
    Curve = ?config(dkg_curve, Config),
    %% Don't put the poc version here
    %% Add it to the map in the tests above
    #{?block_time => BlockTime,
      ?election_interval => Interval,
      ?num_consensus_members => N,
      ?batch_size => BatchSize,
      ?dkg_curve => Curve,
      ?election_version => 6, %% TODO validators
      ?poc_challenge_interval => 15,
      ?poc_v4_exclusion_cells => 10,
      ?poc_v4_parent_res => 11,
      ?poc_v4_prob_bad_rssi => 0.01,
      ?poc_v4_prob_count_wt => 0.3,
      ?poc_v4_prob_good_rssi => 1.0,
      ?poc_v4_prob_no_rssi => 0.5,
      ?poc_v4_prob_rssi_wt => 0.3,
      ?poc_v4_prob_time_wt => 0.3,
      ?poc_v4_randomness_wt => 0.1,
      ?poc_v4_target_challenge_age => 300,
      ?poc_v4_target_exclusion_cells => 6000,
      ?poc_v4_target_prob_edge_wt => 0.2,
      ?poc_v4_target_prob_score_wt => 0.8,
      ?poc_v4_target_score_curve => 5,
      ?poc_target_hex_parent_res => 5,
      ?poc_v5_target_prob_randomness_wt => 0.0}.

do_common_partition_checks(TestCase, Config, VarMap) ->
    Validators = ?config(validators, Config),
    %% Print scores before we begin the test
    InitialScores = gateway_scores(Config),
    ct:pal("InitialScores: ~p", [InitialScores]),
    true = miner_ct_utils:wait_until(
             fun() ->
                     case maps:get(poc_version, VarMap, 1) of
                         V when V >= 10 ->
                             %% There is no path to check, so do both poc-v10 and poc-v11 checks here
                             %% Check that every miner has issued a challenge
                             C1 = check_validators_are_creating_poc_keys(Validators),
                             %% Check there are some poc rewards
                             RewardsMD = get_rewards_md(Config),
                             ct:pal("RewardsMD: ~p", [RewardsMD]),
                             C2 = check_non_empty_poc_rewards(take_poc_challengee_and_witness_rewards(RewardsMD)),
                             ct:pal("C1: ~p, C2: ~p", [C1, C2]),
                             C1 andalso C2;
                         _ ->
                             ok
                     end
             end, 60, 5000),
    %% Print scores after execution
    FinalScores = gateway_scores(Config),
    ct:pal("FinalScores: ~p", [FinalScores]),
    FinalRewards = get_rewards(Config),
    ct:pal("FinalRewards: ~p", [FinalRewards]),
    ok.

balances(Config) ->
    [V | _] = ?config(validators, Config),
    Addresses = ?config(validator_addrs, Config),
    [miner_ct_utils:get_balance(V, Addr) || Addr <- Addresses].

take_poc_challengee_and_witness_rewards(RewardsMD) ->
    %% only take poc_challengee and poc_witness rewards
    POCRewards = lists:foldl(
                   fun({Ht, MDMap}, Acc) ->
                           [{Ht, maps:with([poc_challengee, poc_witness], MDMap)} | Acc]
                   end,
                   [],
                   RewardsMD),
    ct:pal("POCRewards: ~p", [POCRewards]),
    POCRewards.

check_non_empty_poc_rewards(POCRewards) ->
    lists:any(
      fun({_Ht, #{poc_challengee := R1, poc_witness := R2}}) ->
              maps:size(R1) > 0 andalso maps:size(R2) > 0
      end,
      POCRewards).


get_rewards_md(Config) ->
    %% NOTE: It's possible that the calculations below may blow up
    %% since we are folding the entire chain here and some subsequent
    %% ledger_at call in rewards_metadata blows up. Investigate

    [V | _] = ?config(validators, Config),
    Chain = ct_rpc:call(V, blockchain_worker, blockchain, []),
    {ok, Head} = ct_rpc:call(V, blockchain, head_block, [Chain]),

    Filter = fun(T) -> blockchain_txn:type(T) == blockchain_txn_rewards_v2 end,
    Fun = fun(Block, Acc) ->
        case blockchain_utils:find_txn(Block, Filter) of
            [T] ->
                Start = blockchain_txn_rewards_v2:start_epoch(T),
                End = blockchain_txn_rewards_v2:end_epoch(T),
                MDRes = ct_rpc:call(V, blockchain_txn_rewards_v2, calculate_rewards_metadata, [
                    Start,
                    End,
                    Chain
                ]),
                case MDRes of
                    {ok, MD} ->
                        [{blockchain_block:height(Block), MD} | Acc];
                    _ ->
                        Acc
                end;
            _ ->
                Acc
        end
    end,
    Res = ct_rpc:call(V, blockchain, fold_chain, [Fun, [], Head, Chain]),
    Res.


get_rewards(Config) ->
    %% default to rewards_v1
    get_rewards(Config, blockchain_txn_rewards_v2).

get_rewards(Config, RewardType) ->
    [Val | _] = ?config(validators, Config),
    Chain = ct_rpc:call(Val, blockchain_worker, blockchain, []),
    Blocks = ct_rpc:call(Val, blockchain, blocks, [Chain]),
    maps:fold(fun(_, Block, Acc) ->
                      case blockchain_block:transactions(Block) of
                          [] ->
                              Acc;
                          Ts ->
                              Rewards = lists:filter(fun(T) ->
                                                             blockchain_txn:type(T) == RewardType
                                                     end,
                                                     Ts),
                              lists:flatten([Rewards | Acc])
                      end
              end,
              [],
              Blocks).

check_poc_rewards(RewardsTxns) ->
    %% Get all rewards types
    RewardTypes = lists:foldl(fun(RewardTxn, Acc) ->
                                      Types = [blockchain_txn_reward_v1:type(R) || R <- blockchain_txn_rewards_v2:rewards(RewardTxn)],
                                      lists:flatten([Types | Acc])
                              end,
                              [],
                              RewardsTxns),
    lists:any(fun(T) ->
                      T == poc_challengees orelse T == poc_witnesses
              end,
              RewardTypes).

do_common_partition_lying_checks(TestCase, Config, VarMap) ->
    Validators = ?config(validators, Config),
    %% Print scores before we begin the test
    InitialScores = gateway_scores(Config),
    ct:pal("InitialScores: ~p", [InitialScores]),
    %% Print scores before we begin the test
    InitialBalances = balances(Config),
    ct:pal("InitialBalances: ~p", [InitialBalances]),

    true = miner_ct_utils:wait_until(
             fun() ->
                     case maps:get(poc_version, VarMap, 11) of
                         V when V > 10 ->
                             %% Check that every miner has issued a challenge
                             C1 = check_validators_are_creating_poc_keys(Validators),
                             %% TODO: What to check when the partitioned nodes are lying about their locations
                             C1;
                         _ ->
                             %% Check that every miner has issued a challenge
                             C1 = check_validators_are_creating_poc_keys(Validators),
                             %% Since we have two static location partitioned networks, where
                             %% both are lying about their distances, the paths should
                             %% never get longer than 1
                             C2 = check_partitioned_lying_path_growth(TestCase, Validators),
                             C1 andalso C2
                     end
             end,
             40, 5000),
    %% Print scores after execution
    FinalScores = gateway_scores(Config),
    ct:pal("FinalScores: ~p", [FinalScores]),
    %% Print rewards
    Rewards = get_rewards(Config),
    ct:pal("Rewards: ~p", [Rewards]),
    %% Print balances after execution
    FinalBalances = balances(Config),
    ct:pal("FinalBalances: ~p", [FinalBalances]),
    %% There should be no poc_witness or poc_challengees rewards
    ?assert(not check_poc_rewards(Rewards)),
    ok.

extra_vars(poc_v11) ->
    POCVars = maps:merge(extra_vars(poc_v10), miner_poc_test_utils:poc_v11_vars()),
    RewardVars = #{reward_version => 5, rewards_txn_version => 2},
    maps:merge(POCVars, RewardVars);
extra_vars(poc_v10) ->
    maps:merge(extra_poc_vars(),
               #{?poc_version => 10,
                 ?data_aggregation_version => 2,
                 ?consensus_percent => 0.06,
                 ?dc_percent => 0.325,
                 ?poc_challengees_percent => 0.18,
                 ?poc_challengers_percent => 0.0095,
                 ?poc_witnesses_percent => 0.0855,
                 ?securities_percent => 0.34,
                 ?reward_version => 5,
                 ?rewards_txn_version => 2,
                 ?poc_challenge_rate => 1,
                 ?poc_challenger_type => validator,
                 ?election_interval => 10,
                 ?block_time => 5000
                });
extra_vars(poc_v8) ->
    maps:merge(extra_poc_vars(), #{?poc_version => 8});
extra_vars(_) ->
    {error, poc_v8_and_above_only}.

location_sets(poc_dist_v11_partitioned_test) ->
    {sets:from_list(?AUSTINLOCS1), sets:from_list(?LALOCS)};
location_sets(poc_dist_v10_partitioned_test) ->
    {sets:from_list(?AUSTINLOCS1), sets:from_list(?LALOCS)};
location_sets(poc_dist_v8_partitioned_test) ->
    {sets:from_list(?AUSTINLOCS1), sets:from_list(?LALOCS)};
location_sets(_TestCase) ->
    {sets:from_list(?SFLOCS), sets:from_list(?NYLOCS)}.

extra_poc_vars() ->
    #{?poc_good_bucket_low => -132,
      ?poc_good_bucket_high => -80,
      ?poc_v5_target_prob_randomness_wt => 1.0,
      ?poc_v4_target_prob_edge_wt => 0.0,
      ?poc_v4_target_prob_score_wt => 0.0,
      ?poc_v4_prob_rssi_wt => 0.0,
      ?poc_v4_prob_time_wt => 0.0,
      ?poc_v4_randomness_wt => 0.5,
      ?poc_v4_prob_count_wt => 0.0,
      ?poc_centrality_wt => 0.5,
      ?poc_max_hop_cells => 2000}.

check_subsequent_path_growth(ReceiptMap) ->
    PathLengths = [ length(blockchain_txn_poc_receipts_v2:path(Txn)) || {_, Txn} <- lists:flatten(maps:values(ReceiptMap)) ],
    ct:pal("PathLengths: ~p", [PathLengths]),
    lists:any(fun(L) -> L > 1 end, PathLengths).

signatures(ConsensusMembers, BinBlock) ->
    lists:foldl(
        fun({A, {_, _, F}}, Acc) ->
            Sig = F(BinBlock),
            [{A, Sig}|Acc]
        end
        ,[]
        ,ConsensusMembers
    ).
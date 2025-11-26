pub mod abbot_utils {
    use access_control::{IAccessControlDispatcher, IAccessControlDispatcherTrait};
    use opus::core::roles::{sentinel_roles, shrine_roles};
    use opus::interfaces::IAbbot::IAbbotDispatcher;
    use opus::interfaces::IGate::IGateDispatcher;
    use opus::interfaces::ISentinel::ISentinelDispatcher;
    use opus::interfaces::IShrine::IShrineDispatcher;
    use opus::tests::common;
    use opus::tests::sentinel::utils::sentinel_utils;
    use snforge_std::{CheatSpan, ContractClass, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare};
    use starknet::ContractAddress;
    use wadray::Wad;

    // Struct to group together all contract classes
    // needed for abbot tests
    #[derive(Copy, Drop)]
    pub struct AbbotTestClasses {
        pub abbot: Option<ContractClass>,
        pub sentinel: Option<ContractClass>,
        pub token: Option<ContractClass>,
        pub gate: Option<ContractClass>,
        pub shrine: Option<ContractClass>,
    }

    #[derive(Copy, Drop)]
    pub struct AbbotTestConfig {
        pub abbot: IAbbotDispatcher,
        pub sentinel: ISentinelDispatcher,
        pub shrine: IShrineDispatcher,
        pub yangs: Span<ContractAddress>,
        pub gates: Span<IGateDispatcher>,
    }

    #[derive(Copy, Drop)]
    pub struct AbbotTestTrove {
        pub trove_id: u64,
        pub trove_owner: ContractAddress,
        pub yang_asset_amts: Span<u128>,
        pub forge_amt: Wad,
    }

    //
    // Constants
    //

    pub const SUBSEQUENT_ETH_DEPOSIT_AMT: u128 = 2345000000000000000; // 2.345 (Wad);
    pub const SUBSEQUENT_WBTC_DEPOSIT_AMT: u128 = 44300000; // 0.443 (WBTC decimals);

    pub const INITIAL_ASSET_AMTS: [u128; 2] = [
        common::LARGE_ETH_DEPOSIT, common::LARGE_WBTC_DEPOSIT
    ];

    pub const OPEN_TROVE_YANG_ASSET_AMTS: [u128; 2] = [
        common::MEDIUM_ETH_DEPOSIT, common::MEDIUM_WBTC_DEPOSIT
    ];

    pub const SUBSEQUENT_DEPOSIT_AMTS: [u128; 2] = [
        SUBSEQUENT_ETH_DEPOSIT_AMT, SUBSEQUENT_WBTC_DEPOSIT_AMT
    ];

    //
    // Test setup helpers
    //

    pub fn declare_contracts() -> AbbotTestClasses {
        AbbotTestClasses {
            abbot: Option::Some(*declare("abbot").unwrap().contract_class()),
            sentinel: Option::Some(*declare("sentinel").unwrap().contract_class()),
            token: Option::Some(common::declare_token()),
            gate: Option::Some(*declare("gate").unwrap().contract_class()),
            shrine: Option::Some(*declare("shrine").unwrap().contract_class()),
        }
    }

    pub fn abbot_deploy(classes: Option<AbbotTestClasses>) -> AbbotTestConfig {
        let classes = classes.unwrap_or(declare_contracts());
        let sentinel_utils::SentinelTestConfig {
            sentinel, shrine, yangs, gates,
        } =
            sentinel_utils::deploy_sentinel_with_gates(
                Option::Some(
                    sentinel_utils::SentinelTestClasses {
                        sentinel: classes.sentinel, token: classes.token, gate: classes.gate, shrine: classes.shrine,
                    },
                ),
            );

        let calldata: Array<felt252> = array![shrine.contract_address.into(), sentinel.contract_address.into()];

        let (abbot_addr, _) = classes.abbot.unwrap().deploy(@calldata).expect('abbot deploy failed');

        let abbot = IAbbotDispatcher { contract_address: abbot_addr };

        // Grant Shrine roles to Abbot
        cheat_caller_address(shrine.contract_address, common::SHRINE_ADMIN, CheatSpan::TargetCalls(1));
        let shrine_ac = IAccessControlDispatcher { contract_address: shrine.contract_address };
        shrine_ac.grant_role(shrine_roles::ABBOT, abbot_addr);

        // Grant Sentinel roles to Abbot
        cheat_caller_address(sentinel.contract_address, common::SENTINEL_ADMIN, CheatSpan::TargetCalls(1));
        let sentinel_ac = IAccessControlDispatcher { contract_address: sentinel.contract_address };
        sentinel_ac.grant_role(sentinel_roles::ABBOT, abbot_addr);

        AbbotTestConfig { shrine, sentinel, abbot, yangs, gates }
    }

    pub fn deploy_abbot_and_open_trove(classes: Option<AbbotTestClasses>) -> (AbbotTestConfig, AbbotTestTrove) {
        let abbot_test_config = abbot_deploy(classes);
        let trove_owner: ContractAddress = common::TROVE1_OWNER_ADDR;

        let forge_amt: Wad = common::MEDIUM_FORGE.into();
        common::fund_user(trove_owner, abbot_test_config.yangs, INITIAL_ASSET_AMTS.span());
        let yang_asset_amts: Span<u128> = OPEN_TROVE_YANG_ASSET_AMTS.span();
        let trove_id: u64 = common::open_trove_helper(
            abbot_test_config.abbot,
            trove_owner,
            abbot_test_config.yangs,
            yang_asset_amts,
            abbot_test_config.gates,
            forge_amt,
        );

        (abbot_test_config, AbbotTestTrove { trove_owner, trove_id, yang_asset_amts, forge_amt })
    }
}

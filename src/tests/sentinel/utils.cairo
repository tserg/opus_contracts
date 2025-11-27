pub mod sentinel_utils {
    use core::num::traits::Pow;
    use opus::core::roles::{sentinel_roles, shrine_roles};
    use opus::interfaces::IERC20::IERC20DispatcherTrait;
    use opus::interfaces::IGate::IGateDispatcher;
    use opus::interfaces::ISentinel::{ISentinelDispatcher, ISentinelDispatcherTrait};
    use opus::interfaces::IShrine::IShrineDispatcher;
    use opus::tests::common;
    use opus::tests::gate::utils::gate_utils;
    use opus::tests::shrine::utils::shrine_utils;
    use snforge_std::{CheatSpan, ContractClass, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare};
    use starknet::ContractAddress;
    use wadray::WAD_ONE;

    // Struct to group together all contract classes
    // needed for abbot tests
    #[derive(Copy, Drop)]
    pub struct SentinelTestClasses {
        pub sentinel: Option<ContractClass>,
        pub token: Option<ContractClass>,
        pub gate: Option<ContractClass>,
        pub shrine: Option<ContractClass>,
    }

    #[derive(Copy, Drop)]
    pub struct SentinelTestConfig {
        pub shrine: IShrineDispatcher,
        pub sentinel: ISentinelDispatcher,
        pub yangs: Span<ContractAddress>,
        pub gates: Span<IGateDispatcher>,
    }

    //
    // Constants
    //

    pub const ETH_ASSET_MAX: u128 = 1000 * WAD_ONE; // 1000 (wad)
    pub const WBTC_ASSET_MAX: u128 = 100000000000; // 1000 * 10**8


    //
    // Test setup
    //

    pub fn declare_contracts() -> SentinelTestClasses {
        SentinelTestClasses {
            sentinel: Option::Some(*declare("sentinel").unwrap().contract_class()),
            token: Option::Some(common::declare_token()),
            gate: Option::Some(*declare("gate").unwrap().contract_class()),
            shrine: Option::Some(*declare("shrine").unwrap().contract_class()),
        }
    }

    pub fn deploy_sentinel(classes: Option<SentinelTestClasses>) -> (ISentinelDispatcher, IShrineDispatcher) {
        let classes = classes.unwrap_or(declare_contracts());

        let shrine: IShrineDispatcher = shrine_utils::shrine_deploy_and_setup(classes.shrine);

        let calldata: Array<felt252> = array![common::SENTINEL_ADMIN.into(), shrine.contract_address.into()];

        let (sentinel_addr, _) = classes.sentinel.unwrap().deploy(@calldata).expect('sentinel deploy failed');

        // Grant `abbot` role to `mock_abbot`
        common::grant_role_for_address(sentinel_addr, sentinel_roles::ABBOT, common::MOCK_ABBOT);

        common::grant_role_for_address(shrine.contract_address, shrine_roles::SENTINEL, sentinel_addr);
        common::grant_role_for_address(shrine.contract_address, shrine_roles::ABBOT, common::MOCK_ABBOT);

        (ISentinelDispatcher { contract_address: sentinel_addr }, shrine)
    }

    pub fn deploy_sentinel_with_gates(classes: Option<SentinelTestClasses>) -> SentinelTestConfig {
        let classes = classes.unwrap_or(declare_contracts());
        let (sentinel, shrine) = deploy_sentinel(Option::Some(classes));

        let (eth, eth_gate) = add_eth_yang(sentinel, shrine, classes.token, classes.gate);
        let (wbtc, wbtc_gate) = add_wbtc_yang(sentinel, shrine, classes.token, classes.gate);

        let yangs: Span<ContractAddress> = array![eth, wbtc].span();
        let gates: Span<IGateDispatcher> = array![eth_gate, wbtc_gate].span();

        SentinelTestConfig { sentinel, shrine, yangs, gates }
    }

    pub fn deploy_gate_and_add_yang(
        shrine: IShrineDispatcher,
        sentinel: ISentinelDispatcher,
        gate_class: Option<ContractClass>,
        yang: ContractAddress,
        asset_max: u128,
        asset_params: common::YangParams,
    ) -> (ContractAddress, IGateDispatcher) {
        let gate: IGateDispatcher = gate_utils::gate_deploy(
            yang, shrine.contract_address, sentinel.contract_address, gate_class,
        );

        let yang_erc20 = common::erc20(yang);
        let initial_deposit_amt: u128 = get_initial_asset_amt(yang);

        // The mock sentinel admin is funded during token deployment
        cheat_caller_address(yang, common::SENTINEL_ADMIN, CheatSpan::TargetCalls(1));
        yang_erc20.approve(sentinel.contract_address, initial_deposit_amt.into());

        cheat_caller_address(sentinel.contract_address, common::SENTINEL_ADMIN, CheatSpan::TargetCalls(1));
        sentinel
            .add_yang(
                yang,
                // Re-use ETH parameters
                asset_max,
                asset_params.threshold.into(),
                asset_params.start_price.into(),
                asset_params.base_rate.into(),
                gate.contract_address,
            );

        (yang, gate)
    }


    pub fn add_eth_vault_yang(
        sentinel: ISentinelDispatcher,
        shrine: IShrineDispatcher,
        vault_class: Option<ContractClass>,
        gate_class: ContractClass,
        eth: ContractAddress,
    ) -> (ContractAddress, IGateDispatcher) {
        let eth_vault: ContractAddress = common::eth_vault_deploy(vault_class, eth);
        let eth_params = common::YANG1_PARAMS;
        deploy_gate_and_add_yang(shrine, sentinel, Option::Some(gate_class), eth_vault, ETH_ASSET_MAX, eth_params)
    }

    pub fn add_wbtc_vault_yang(
        sentinel: ISentinelDispatcher,
        shrine: IShrineDispatcher,
        vault_class: Option<ContractClass>,
        gate_class: ContractClass,
        wbtc: ContractAddress,
    ) -> (ContractAddress, IGateDispatcher) {
        let wbtc_vault: ContractAddress = common::wbtc_vault_deploy(vault_class, wbtc);
        let wbtc_params = common::YANG2_PARAMS;
        deploy_gate_and_add_yang(shrine, sentinel, Option::Some(gate_class), wbtc_vault, WBTC_ASSET_MAX, wbtc_params)
    }

    pub fn add_vaults_to_sentinel(
        shrine: IShrineDispatcher,
        sentinel: ISentinelDispatcher,
        gate_class: ContractClass,
        vault_class: Option<ContractClass>,
        eth: ContractAddress,
        wbtc: ContractAddress,
    ) -> (Span<ContractAddress>, Span<IGateDispatcher>) {
        let vault_class = Option::Some(vault_class.unwrap_or(*declare("erc4626_mintable").unwrap().contract_class()));

        let (eth_vault, eth_vault_gate) = add_eth_vault_yang(sentinel, shrine, vault_class, gate_class, eth);
        let (wbtc_vault, wbtc_vault_gate) = add_wbtc_vault_yang(sentinel, shrine, vault_class, gate_class, wbtc);

        let vaults: Span<ContractAddress> = array![eth_vault, wbtc_vault].span();
        let gates: Span<IGateDispatcher> = array![eth_vault_gate, wbtc_vault_gate].span();

        (vaults, gates)
    }

    pub fn deploy_sentinel_with_eth_gate(classes: Option<SentinelTestClasses>) -> SentinelTestConfig {
        let classes = classes.unwrap_or(declare_contracts());

        let (sentinel, shrine) = deploy_sentinel(Option::Some(classes));
        let (eth, eth_gate) = add_eth_yang(sentinel, shrine, classes.token, classes.gate);

        let yangs: Span<ContractAddress> = array![eth].span();
        let gates: Span<IGateDispatcher> = array![eth_gate].span();

        SentinelTestConfig { sentinel, shrine, yangs, gates }
    }

    pub fn add_eth_yang(
        sentinel: ISentinelDispatcher,
        shrine: IShrineDispatcher,
        token_class: Option<ContractClass>,
        gate_class: Option<ContractClass>,
    ) -> (ContractAddress, IGateDispatcher) {
        let eth: ContractAddress = common::eth_token_deploy(token_class);
        let eth_params = common::YANG1_PARAMS;
        deploy_gate_and_add_yang(shrine, sentinel, gate_class, eth, ETH_ASSET_MAX, eth_params)
    }

    pub fn add_wbtc_yang(
        sentinel: ISentinelDispatcher,
        shrine: IShrineDispatcher,
        token_class: Option<ContractClass>,
        gate_class: Option<ContractClass>,
    ) -> (ContractAddress, IGateDispatcher) {
        let wbtc: ContractAddress = common::wbtc_token_deploy(token_class);
        let wbtc_params = common::YANG2_PARAMS;
        deploy_gate_and_add_yang(shrine, sentinel, gate_class, wbtc, WBTC_ASSET_MAX, wbtc_params)
    }

    pub fn get_initial_asset_amt(asset_addr: ContractAddress) -> u128 {
        10_u128.pow((common::erc20(asset_addr).decimals() / 2).into())
    }
}

pub mod gate_utils {
    use core::num::traits::Zero;
    use opus::interfaces::IERC20::{IERC20Dispatcher, IMintableDispatcher, IMintableDispatcherTrait};
    use opus::interfaces::IGate::IGateDispatcher;
    use opus::interfaces::IShrine::{IShrineDispatcher, IShrineDispatcherTrait};
    use opus::tests::common;
    use opus::tests::shrine::utils::shrine_utils;
    use snforge_std::{
        CheatSpan, ContractClass, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare,
        start_cheat_block_timestamp_global,
    };
    use starknet::ContractAddress;

    //
    // Address constants
    //

    //
    // Test setup helpers
    //

    pub fn gate_deploy(
        token: ContractAddress, shrine: ContractAddress, sentinel: ContractAddress, gate_class: Option<ContractClass>,
    ) -> ContractAddress {
        start_cheat_block_timestamp_global(shrine_utils::DEPLOYMENT_TIMESTAMP);

        let calldata: Array<felt252> = array![shrine.into(), token.into(), sentinel.into()];

        let gate_class = gate_class.unwrap_or(*declare("gate").unwrap().contract_class());
        let (gate_addr, _) = gate_class.deploy(@calldata).expect('gate deploy failed');
        gate_addr
    }

    pub fn eth_gate_deploy(
        token_class: Option<ContractClass>,
    ) -> (IShrineDispatcher, IERC20Dispatcher, IGateDispatcher) {
        let shrine = shrine_utils::shrine_deploy_and_setup(Option::None);
        let eth: ContractAddress = common::eth_token_deploy(token_class);
        let gate: ContractAddress = gate_deploy(eth, shrine.contract_address, common::MOCK_SENTINEL, Option::None);
        (shrine, common::erc20(eth), IGateDispatcher { contract_address: gate })
    }

    pub fn wbtc_gate_deploy(
        token_class: Option<ContractClass>,
    ) -> (IShrineDispatcher, IERC20Dispatcher, IGateDispatcher) {
        let shrine = shrine_utils::shrine_deploy_and_setup(Option::None);
        let wbtc: ContractAddress = common::wbtc_token_deploy(token_class);
        let gate: ContractAddress = gate_deploy(wbtc, shrine.contract_address, common::MOCK_SENTINEL, Option::None);
        (shrine, common::erc20(wbtc), IGateDispatcher { contract_address: gate })
    }

    pub fn add_eth_as_yang(shrine: IShrineDispatcher, eth: IERC20Dispatcher) {
        cheat_caller_address(shrine.contract_address, common::SHRINE_ADMIN, CheatSpan::TargetCalls(2));
        let eth_params = common::YANG1_PARAMS;
        shrine
            .add_yang(
                eth.contract_address,
                eth_params.threshold.into(),
                eth_params.start_price.into(),
                eth_params.base_rate.into(),
                Zero::zero() // initial amount
            );
    }

    pub fn add_wbtc_as_yang(shrine: IShrineDispatcher, wbtc: IERC20Dispatcher) {
        cheat_caller_address(shrine.contract_address, common::SHRINE_ADMIN, CheatSpan::TargetCalls(2));
        shrine
            .add_yang(
                wbtc.contract_address,
                common::YANG2_THRESHOLD.into(),
                common::YANG2_START_PRICE.into(),
                common::YANG2_BASE_RATE.into(),
                Zero::zero() // initial amount
            );
    }

    pub fn rebase(gate: IGateDispatcher, token: IERC20Dispatcher, amount: u128) {
        IMintableDispatcher { contract_address: token.contract_address }.mint(gate.contract_address, amount.into());
    }
}

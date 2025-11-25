pub mod gate_utils {
    use core::num::traits::{Bounded, Zero};
    use opus::interfaces::IERC20::{IERC20DispatcherTrait, IMintableDispatcher, IMintableDispatcherTrait};
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

    pub fn eth_gate_deploy(token_class: Option<ContractClass>) -> (ContractAddress, ContractAddress, ContractAddress) {
        let shrine = shrine_utils::shrine_deploy_and_setup(Option::None);
        let eth: ContractAddress = common::eth_token_deploy(token_class);
        let gate: ContractAddress = gate_deploy(eth, shrine, common::MOCK_SENTINEL, Option::None);
        (shrine, eth, gate)
    }

    pub fn wbtc_gate_deploy(token_class: Option<ContractClass>) -> (ContractAddress, ContractAddress, ContractAddress) {
        let shrine = shrine_utils::shrine_deploy_and_setup(Option::None);
        let wbtc: ContractAddress = common::wbtc_token_deploy(token_class);
        let gate: ContractAddress = gate_deploy(wbtc, shrine, common::MOCK_SENTINEL, Option::None);
        (shrine, wbtc, gate)
    }

    pub fn add_eth_as_yang(shrine: ContractAddress, eth: ContractAddress) {
        cheat_caller_address(shrine, common::SHRINE_ADMIN, CheatSpan::TargetCalls(2));
        let shrine = IShrineDispatcher { contract_address: shrine };
        shrine
            .add_yang(
                eth,
                common::YANG1_THRESHOLD.into(),
                common::YANG1_START_PRICE.into(),
                common::YANG1_BASE_RATE.into(),
                Zero::zero() // initial amount
            );
    }

    pub fn add_wbtc_as_yang(shrine: ContractAddress, wbtc: ContractAddress) {
        cheat_caller_address(shrine, common::SHRINE_ADMIN, CheatSpan::TargetCalls(2));
        let shrine = IShrineDispatcher { contract_address: shrine };
        shrine
            .add_yang(
                wbtc,
                common::YANG2_THRESHOLD.into(),
                common::YANG2_START_PRICE.into(),
                common::YANG2_BASE_RATE.into(),
                Zero::zero() // initial amount
            );
    }

    pub fn approve_gate_for_token(gate: ContractAddress, token: ContractAddress, user: ContractAddress) {
        // user no-limit approves gate to handle their share of token
        cheat_caller_address(token, user, CheatSpan::TargetCalls(1));
        common::erc20(token).approve(gate, Bounded::MAX);
    }

    pub fn rebase(gate: ContractAddress, token: ContractAddress, amount: u128) {
        IMintableDispatcher { contract_address: token }.mint(gate, amount.into());
    }
}

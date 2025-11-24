pub mod caretaker_utils {
    use opus::core::roles::{sentinel_roles, shrine_roles};
    use opus::interfaces::IAbbot::IAbbotDispatcher;
    use opus::interfaces::ICaretaker::ICaretakerDispatcher;
    use opus::interfaces::IGate::IGateDispatcher;
    use opus::interfaces::ISentinel::ISentinelDispatcher;
    use opus::interfaces::IShrine::IShrineDispatcher;
    use opus::tests::abbot::utils::abbot_utils;
    use opus::tests::common;
    use opus::tests::equalizer::utils::equalizer_utils;
    use opus::tests::shrine::utils::shrine_utils;
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, declare,
        start_cheat_block_timestamp_global,
    };
    use starknet::ContractAddress;

    #[derive(Copy, Drop)]
    pub struct CaretakerTestConfig {
        pub abbot: IAbbotDispatcher,
        pub caretaker: ICaretakerDispatcher,
        pub sentinel: ISentinelDispatcher,
        pub shrine: IShrineDispatcher,
        pub yangs: Span<ContractAddress>,
        pub gates: Span<IGateDispatcher>,
    }


    pub fn caretaker_deploy() -> CaretakerTestConfig {
        start_cheat_block_timestamp_global(shrine_utils::DEPLOYMENT_TIMESTAMP);

        let abbot_utils::AbbotTestConfig {
            shrine, sentinel, abbot, yangs, gates,
        } = abbot_utils::abbot_deploy(Option::None);
        let equalizer_utils::EqualizerTestConfig {
            shrine, equalizer, ..,
        } = equalizer_utils::equalizer_deploy_with_shrine(shrine.contract_address, Option::None);

        let calldata: Array<felt252> = array![
            common::CARETAKER_ADMIN.into(),
            shrine.contract_address.into(),
            abbot.contract_address.into(),
            sentinel.contract_address.into(),
            equalizer.contract_address.into(),
        ];

        let caretaker_class = declare("caretaker").unwrap().contract_class();
        let (caretaker, _) = caretaker_class.deploy(@calldata).expect('caretaker deploy failed');

        // allow Caretaker to do its business with Shrine
        common::grant_role_for_address(shrine.contract_address, shrine_roles::CARETAKER, caretaker);

        // allow Caretaker to call exit in Sentinel during shut
        common::grant_role_for_address(sentinel.contract_address, sentinel_roles::CARETAKER, caretaker);

        let caretaker = ICaretakerDispatcher { contract_address: caretaker };

        CaretakerTestConfig { caretaker, shrine, abbot, sentinel, yangs, gates }
    }

    pub fn only_eth(
        yangs: Span<ContractAddress>, gates: Span<IGateDispatcher>,
    ) -> (Span<ContractAddress>, Span<IGateDispatcher>, Span<u128>) {
        let mut eth_yang = array![*yangs[0]];
        let mut eth_gate = array![*gates[0]];
        let mut eth_amount = array![common::MEDIUM_ETH_DEPOSIT];

        (eth_yang.span(), eth_gate.span(), eth_amount.span())
    }
}

pub mod receptor_utils {
    use access_control::{IAccessControlDispatcher, IAccessControlDispatcherTrait};
    use opus::core::roles::shrine_roles;
    use opus::interfaces::IReceptor::IReceptorDispatcher;
    use opus::interfaces::IShrine::IShrineDispatcher;
    use opus::mock::mock_ekubo_oracle_extension::IMockEkuboOracleExtensionDispatcher;
    use opus::tests::common;
    use opus::tests::shrine::utils::shrine_utils;
    use snforge_std::{
        CheatSpan, ContractClass, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare,
        start_cheat_block_timestamp_global,
    };
    use starknet::ContractAddress;
    use wadray::{WAD_DECIMALS, WAD_ONE};

    #[derive(Copy, Drop)]
    pub struct ReceptorTestConfig {
        pub mock_ekubo_oracle_extension: IMockEkuboOracleExtensionDispatcher,
        pub receptor: IReceptorDispatcher,
        pub shrine: IShrineDispatcher,
        pub quote_tokens: Span<ContractAddress>,
    }

    //
    // constants
    //

    pub const INITIAL_TWAP_DURATION: u64 = 3 * 60 * 60; // 3 hrs
    pub const INITIAL_UPDATE_FREQUENCY: u64 = 30 * 60; // 30 mins

    pub fn invalid_token(token_class: Option<ContractClass>) -> ContractAddress {
        common::deploy_token(
            'Invalid', 'INV', (WAD_DECIMALS + 1).into(), WAD_ONE.into(), common::SHRINE_ADMIN, token_class,
        )
    }


    //
    // Test setup helpers
    //

    pub fn mock_ekubo_oracle_extension_deploy(
        mock_ekubo_oracle_extension_class: Option<ContractClass>,
    ) -> ContractAddress {
        let mut calldata: Array<felt252> = ArrayTrait::new();

        let mock_ekubo_oracle_extension_class = mock_ekubo_oracle_extension_class
            .unwrap_or(common::declare_mock_ekubo_oracle_extension());

        let (mock_ekubo_oracle_extension_addr, _) = mock_ekubo_oracle_extension_class
            .deploy(@calldata)
            .expect('mock ekubo oracle ext failed');

        mock_ekubo_oracle_extension_addr
    }

    pub fn receptor_deploy(
        receptor_class: Option<ContractClass>, token_class: Option<ContractClass>,
    ) -> ReceptorTestConfig {
        start_cheat_block_timestamp_global(shrine_utils::DEPLOYMENT_TIMESTAMP);

        let quote_tokens = common::quote_tokens(token_class);

        let shrine: IShrineDispatcher = shrine_utils::shrine_deploy_with_dummy_yangs(Option::None);
        let mock_ekubo_oracle_extension_addr: ContractAddress = mock_ekubo_oracle_extension_deploy(Option::None);

        let mut calldata: Array<felt252> = array![
            common::SHRINE_ADMIN.into(),
            shrine.contract_address.into(),
            mock_ekubo_oracle_extension_addr.into(),
            INITIAL_UPDATE_FREQUENCY.into(),
            INITIAL_TWAP_DURATION.into(),
            quote_tokens.len().into(),
            (*quote_tokens[0]).into(),
            (*quote_tokens[1]).into(),
            (*quote_tokens[2]).into(),
        ];

        let receptor_class = receptor_class.unwrap_or(*declare("receptor").unwrap().contract_class());
        let (receptor_addr, _) = receptor_class.deploy(@calldata).expect('receptor deploy failed');

        // Grant UPDATE_YIN_SPOT_PRICE role to receptor contract
        common::grant_role_for_address(shrine.contract_address, shrine_roles::RECEPTOR, receptor_addr);

        ReceptorTestConfig {
            shrine,
            receptor: IReceptorDispatcher { contract_address: receptor_addr },
            mock_ekubo_oracle_extension: IMockEkuboOracleExtensionDispatcher {
                contract_address: mock_ekubo_oracle_extension_addr,
            },
            quote_tokens,
        }
    }
}

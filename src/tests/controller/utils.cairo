pub mod controller_utils {
    use access_control::{IAccessControlDispatcher, IAccessControlDispatcherTrait};
    use opus::core::roles::shrine_roles;
    use opus::interfaces::IController::IControllerDispatcher;
    use opus::interfaces::IShrine::{IShrineDispatcher, IShrineDispatcherTrait};
    use opus::tests::common;
    use opus::tests::shrine::utils::shrine_utils;
    use snforge_std::{
        CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare,
        start_cheat_block_timestamp_global,
    };
    use starknet::{ContractAddress, get_block_timestamp};
    use wadray::{RAY_ONE, Wad};

    #[derive(Copy, Drop)]
    pub struct ControllerTestConfig {
        pub controller: IControllerDispatcher,
        pub shrine: IShrineDispatcher,
    }

    // Controller update interval
    pub const ONE_HOUR: u64 = 60 * 60; // 1 hour

    // Default controller parameters
    pub const P_GAIN: u128 = 100 * RAY_ONE; // 100 * RAY_ONE
    pub const I_GAIN: u128 = 0;
    pub const ALPHA_P: u8 = 3;
    pub const BETA_P: u8 = 8;
    pub const ALPHA_I: u8 = 1;
    pub const BETA_I: u8 = 2;

    // Addresses

    pub const ADMIN: ContractAddress = 'controller admin'.try_into().unwrap();

    pub fn deploy_controller() -> ControllerTestConfig {
        let shrine_addr: ContractAddress = shrine_utils::shrine_deploy(Option::None);
        shrine_utils::make_root(shrine_addr, common::SHRINE_ADMIN);

        let calldata: Array<felt252> = array![
            ADMIN.into(),
            shrine_addr.into(),
            P_GAIN.into(),
            I_GAIN.into(),
            ALPHA_P.into(),
            BETA_P.into(),
            ALPHA_I.into(),
            BETA_I.into(),
        ];

        let controller_class = *declare("controller").unwrap().contract_class();
        let (controller_addr, _) = controller_class.deploy(@calldata).expect('controller deploy failed');

        let shrine_ac = IAccessControlDispatcher { contract_address: shrine_addr };
        cheat_caller_address(shrine_addr, common::SHRINE_ADMIN, CheatSpan::TargetCalls(1));
        shrine_ac.grant_role(shrine_roles::CONTROLLER, controller_addr);

        ControllerTestConfig {
            controller: IControllerDispatcher { contract_address: controller_addr },
            shrine: IShrineDispatcher { contract_address: shrine_addr },
        }
    }

    #[inline(always)]
    pub fn set_yin_spot_price(shrine: IShrineDispatcher, spot_price: Wad) {
        cheat_caller_address(shrine.contract_address, common::SHRINE_ADMIN, CheatSpan::TargetCalls(1));
        shrine.update_yin_spot_price(spot_price);
    }

    #[inline(always)]
    pub fn fast_forward_1_hour() {
        start_cheat_block_timestamp_global(get_block_timestamp() + ONE_HOUR);
    }

    #[inline(always)]
    pub fn fast_forward_by_x_minutes(x: u64) {
        start_cheat_block_timestamp_global(get_block_timestamp() + x * 60);
    }
}

pub mod flash_mint_utils {
    use core::num::traits::Zero;
    use opus::core::roles::shrine_roles;
    use opus::interfaces::IFlashMint::IFlashMintDispatcher;
    use opus::interfaces::IShrine::{IShrineDispatcher, IShrineDispatcherTrait};
    use opus::tests::common;
    use opus::tests::shrine::utils::shrine_utils;
    use snforge_std::{CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare};
    use starknet::ContractAddress;
    use wadray::WAD_ONE;

    pub const YIN_TOTAL_SUPPLY: u128 = 20000 * WAD_ONE; // 20000 (Wad)
    pub const DEFAULT_MINT_AMOUNT: u128 = 500 * WAD_ONE; // 500 (Wad)

    // Helper function to build a calldata Span for `FlashMint.flash_loan`
    #[inline(always)]
    pub fn build_calldata(should_return_correct: bool, usage: felt252) -> Span<felt252> {
        array![should_return_correct.into(), usage].span()
    }

    pub fn flash_mint_deploy(shrine: ContractAddress) -> IFlashMintDispatcher {
        let flash_mint_class = declare("flash_mint").unwrap().contract_class();
        let (flash_mint_addr, _) = flash_mint_class.deploy(@array![shrine.into()]).expect('flash_mint deploy failed');

        // Grant flash_mint contract the FLASHMINT role
        common::grant_role_for_address(shrine, shrine_roles::FLASH_MINT, flash_mint_addr);

        IFlashMintDispatcher { contract_address: flash_mint_addr }
    }

    pub fn flash_mint_setup() -> (IShrineDispatcher, IFlashMintDispatcher) {
        let shrine: IShrineDispatcher = shrine_utils::shrine_deploy_with_dummy_yangs(Option::None);
        let flash_mint: IFlashMintDispatcher = flash_mint_deploy(shrine.contract_address);

        shrine_utils::advance_prices_and_set_multiplier(shrine, common::THREE_YANG_ADDRS.span(), 3);

        // Mint some yin in shrine
        cheat_caller_address(shrine.contract_address, common::SHRINE_ADMIN, CheatSpan::TargetCalls(1));
        shrine.inject(Zero::zero(), YIN_TOTAL_SUPPLY.into());
        (shrine, flash_mint)
    }

    pub fn flash_borrower_deploy(flash_mint: ContractAddress) -> ContractAddress {
        let flash_borrower_class = declare("flash_borrower").unwrap().contract_class();
        let (flash_borrower_addr, _) = flash_borrower_class
            .deploy(@array![flash_mint.into()])
            .expect('flsh brrwr deploy failed');
        flash_borrower_addr
    }

    pub fn flash_borrower_setup() -> (IShrineDispatcher, IFlashMintDispatcher, ContractAddress) {
        let (shrine, flash_mint) = flash_mint_setup();
        (shrine, flash_mint, flash_borrower_deploy(flash_mint.contract_address))
    }
}

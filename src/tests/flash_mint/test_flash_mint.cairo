mod test_flash_mint {
    use core::num::traits::Zero;
    use opus::core::flash_mint::flash_mint as flash_mint_contract;
    use opus::interfaces::IERC20::IERC20DispatcherTrait;
    use opus::interfaces::IEqualizer::IEqualizerDispatcherTrait;
    use opus::interfaces::IFlashMint::IFlashMintDispatcherTrait;
    use opus::interfaces::IShrine::IShrineDispatcherTrait;
    use opus::mock::flash_borrower::flash_borrower as flash_borrower_contract;
    use opus::tests::common;
    use opus::tests::equalizer::utils::equalizer_utils;
    use opus::tests::flash_mint::utils::flash_mint_utils;
    use opus::tests::shrine::utils::shrine_utils;
    use snforge_std::{CheatSpan, EventSpyAssertionsTrait, cheat_caller_address, spy_events};
    use starknet::ContractAddress;
    use wadray::{WAD_ONE, Wad};

    //
    // Tests
    //

    #[test]
    fn test_flash_mint_max_loan() {
        let (shrine, flash_mint) = flash_mint_utils::flash_mint_setup();

        // Check that max loan is correct
        let max_loan: u256 = flash_mint.max_flash_loan(shrine.contract_address);
        let expected_max_loan: Wad = flash_mint_utils::YIN_TOTAL_SUPPLY.into()
            * flash_mint_contract::FLASH_MINT_AMOUNT_PCT.into();
        assert(max_loan == expected_max_loan.into(), 'Incorrect max flash loan');
    }

    #[test]
    fn test_flash_mint_debt_ceiling_exceeded_max_loan() {
        let equalizer_utils::EqualizerTestConfig {
            shrine, equalizer, ..,
        } = equalizer_utils::equalizer_deploy(Option::None);
        let flash_mint = flash_mint_utils::flash_mint_deploy(shrine.contract_address);

        let debt_ceiling: Wad = shrine.get_debt_ceiling();

        // deposit 1000 ETH and forge the debt ceiling
        shrine_utils::trove1_deposit(shrine, (1000 * WAD_ONE).into());
        shrine_utils::trove1_forge(shrine, debt_ceiling);
        let eth: ContractAddress = common::YANG1_ADDR;
        let (eth_price, _, _) = shrine.get_current_yang_price(eth);

        // accrue interest to exceed the debt ceiling
        common::advance_intervals(1000);

        // update price to speed up calculation
        cheat_caller_address(shrine.contract_address, common::SHRINE_ADMIN, CheatSpan::TargetCalls(1));
        shrine.advance(eth, eth_price);

        shrine_utils::trove1_deposit(shrine, Zero::zero());

        let surplus: Wad = equalizer.equalize();
        assert(surplus.is_non_zero(), 'no surplus');
        let total_yin: Wad = shrine.get_total_yin();
        assert(total_yin > debt_ceiling, 'below debt ceiling');

        // Check that max loan is correct
        let max_loan: u256 = flash_mint.max_flash_loan(shrine.contract_address);
        let expected_max_loan: u256 = (total_yin * flash_mint_contract::FLASH_MINT_AMOUNT_PCT.into()).into();
        assert(max_loan == expected_max_loan, 'Incorrect max flash loan');
    }

    #[test]
    fn test_flash_fee() {
        let (shrine, flash_mint) = flash_mint_utils::flash_mint_setup();

        // Check that flash fee is correct
        assert(flash_mint.flash_fee(shrine.contract_address, 0xdeadbeefdead_u256).is_zero(), 'Incorrect flash fee');
    }

    #[test]
    fn test_flash_mint_pass() {
        let (shrine, flash_mint, borrower) = flash_mint_utils::flash_borrower_setup();

        let mut spy = spy_events();

        let yin = common::erc20(shrine.contract_address);

        let mut calldata: Span<felt252> = flash_mint_utils::build_calldata(true, flash_borrower_contract::VALID_USAGE);

        // `borrower` contains a check that ensures that `flash_mint` actually transferred
        // the full flash_loan amount
        let flash_mint_caller: ContractAddress = common::NON_ZERO_ADDR;
        cheat_caller_address(flash_mint.contract_address, flash_mint_caller, CheatSpan::TargetCalls(6));

        let first_loan_amt: u256 = 1;
        flash_mint.flash_loan(borrower, shrine.contract_address, first_loan_amt, calldata);

        assert(yin.balance_of(borrower).is_zero(), 'Wrong yin bal after flash_mint 1');

        let second_loan_amt: u256 = flash_mint_utils::DEFAULT_MINT_AMOUNT.into();
        flash_mint.flash_loan(borrower, shrine.contract_address, second_loan_amt, calldata);
        assert(yin.balance_of(borrower).is_zero(), 'Wrong yin bal after flash_mint 2');

        let third_loan_amt: u256 = (1000 * WAD_ONE).into();
        flash_mint.flash_loan(borrower, shrine.contract_address, third_loan_amt, calldata);
        assert(yin.balance_of(borrower).is_zero(), 'Wrong yin bal after flash_mint 3');

        // check that flash loan still functions normally when yin supply is at debt ceiling
        let debt_ceiling: Wad = shrine.get_debt_ceiling();
        let debt_to_ceiling: Wad = debt_ceiling - shrine.get_total_yin();
        cheat_caller_address(shrine.contract_address, common::SHRINE_ADMIN, CheatSpan::TargetCalls(1));
        shrine.inject(common::NON_ZERO_ADDR, debt_to_ceiling);

        let fourth_loan_amt: u256 = (debt_ceiling * flash_mint_contract::FLASH_MINT_AMOUNT_PCT.into()).into();
        flash_mint.flash_loan(borrower, shrine.contract_address, fourth_loan_amt, calldata);
        assert(yin.balance_of(borrower).is_zero(), 'Wrong yin bal after flash_mint 4');

        // check that flash loan still functions normally when yin supply is at debt ceiling
        // and the budget has a deficit
        cheat_caller_address(shrine.contract_address, common::SHRINE_ADMIN, CheatSpan::TargetCalls(1));
        shrine.adjust_budget((1000 * WAD_ONE).into());

        let fifth_loan_amt: u256 = (debt_ceiling * flash_mint_contract::FLASH_MINT_AMOUNT_PCT.into()).into();
        flash_mint.flash_loan(borrower, shrine.contract_address, fifth_loan_amt, calldata);
        assert(yin.balance_of(borrower).is_zero(), 'Wrong yin bal after flash_mint 5');

        // check that flash loan still functions normally when yin supply is at debt ceiling
        // and the budget has a surplus
        cheat_caller_address(shrine.contract_address, common::SHRINE_ADMIN, CheatSpan::TargetCalls(1));
        shrine.adjust_budget((2000 * WAD_ONE).into());

        let sixth_loan_amt: u256 = (debt_ceiling * flash_mint_contract::FLASH_MINT_AMOUNT_PCT.into()).into();
        flash_mint.flash_loan(borrower, shrine.contract_address, sixth_loan_amt, calldata);
        assert(yin.balance_of(borrower).is_zero(), 'Wrong yin bal after flash_mint 6');

        let expected_events = array![
            (
                flash_mint.contract_address,
                flash_mint_contract::Event::FlashMint(
                    flash_mint_contract::FlashMint {
                        initiator: flash_mint_caller,
                        receiver: borrower,
                        token: shrine.contract_address,
                        amount: first_loan_amt,
                    },
                ),
            ),
            (
                flash_mint.contract_address,
                flash_mint_contract::Event::FlashMint(
                    flash_mint_contract::FlashMint {
                        initiator: flash_mint_caller,
                        receiver: borrower,
                        token: shrine.contract_address,
                        amount: second_loan_amt,
                    },
                ),
            ),
            (
                flash_mint.contract_address,
                flash_mint_contract::Event::FlashMint(
                    flash_mint_contract::FlashMint {
                        initiator: flash_mint_caller,
                        receiver: borrower,
                        token: shrine.contract_address,
                        amount: third_loan_amt,
                    },
                ),
            ),
            (
                flash_mint.contract_address,
                flash_mint_contract::Event::FlashMint(
                    flash_mint_contract::FlashMint {
                        initiator: flash_mint_caller,
                        receiver: borrower,
                        token: shrine.contract_address,
                        amount: fourth_loan_amt,
                    },
                ),
            ),
            (
                flash_mint.contract_address,
                flash_mint_contract::Event::FlashMint(
                    flash_mint_contract::FlashMint {
                        initiator: flash_mint_caller,
                        receiver: borrower,
                        token: shrine.contract_address,
                        amount: fifth_loan_amt,
                    },
                ),
            ),
            (
                flash_mint.contract_address,
                flash_mint_contract::Event::FlashMint(
                    flash_mint_contract::FlashMint {
                        initiator: flash_mint_caller,
                        receiver: borrower,
                        token: shrine.contract_address,
                        amount: sixth_loan_amt,
                    },
                ),
            ),
        ];

        spy.assert_emitted(@expected_events);

        // Flash borrower events
        let expected_events = array![
            (
                borrower,
                flash_borrower_contract::Event::FlashLoancall_dataReceived(
                    flash_borrower_contract::FlashLoancall_dataReceived {
                        initiator: flash_mint_caller,
                        token: shrine.contract_address,
                        amount: first_loan_amt,
                        fee: 0,
                        call_data: calldata,
                    },
                ),
            ),
            (
                borrower,
                flash_borrower_contract::Event::FlashLoancall_dataReceived(
                    flash_borrower_contract::FlashLoancall_dataReceived {
                        initiator: flash_mint_caller,
                        token: shrine.contract_address,
                        amount: second_loan_amt,
                        fee: 0,
                        call_data: calldata,
                    },
                ),
            ),
            (
                borrower,
                flash_borrower_contract::Event::FlashLoancall_dataReceived(
                    flash_borrower_contract::FlashLoancall_dataReceived {
                        initiator: flash_mint_caller,
                        token: shrine.contract_address,
                        amount: third_loan_amt,
                        fee: 0,
                        call_data: calldata,
                    },
                ),
            ),
            (
                borrower,
                flash_borrower_contract::Event::FlashLoancall_dataReceived(
                    flash_borrower_contract::FlashLoancall_dataReceived {
                        initiator: flash_mint_caller,
                        token: shrine.contract_address,
                        amount: fourth_loan_amt,
                        fee: 0,
                        call_data: calldata,
                    },
                ),
            ),
        ];

        spy.assert_emitted(@expected_events);
    }

    #[test]
    #[should_panic(expected: 'FM: amount exceeds maximum')]
    fn test_flash_mint_excess_minting() {
        let (shrine, flash_mint, borrower) = flash_mint_utils::flash_borrower_setup();
        flash_mint
            .flash_loan(
                borrower,
                shrine.contract_address,
                1000000000000000000001_u256,
                flash_mint_utils::build_calldata(true, flash_borrower_contract::VALID_USAGE),
            );
    }

    #[test]
    #[should_panic(expected: 'FM: on_flash_loan failed')]
    fn test_flash_mint_incorrect_return() {
        let (shrine, flash_mint, borrower) = flash_mint_utils::flash_borrower_setup();
        flash_mint
            .flash_loan(
                borrower,
                shrine.contract_address,
                flash_mint_utils::DEFAULT_MINT_AMOUNT.into(),
                flash_mint_utils::build_calldata(false, flash_borrower_contract::VALID_USAGE),
            );
    }

    #[test]
    #[should_panic(expected: 'SH: Insufficient yin balance')]
    fn test_flash_mint_steal() {
        let (shrine, flash_mint, borrower) = flash_mint_utils::flash_borrower_setup();
        flash_mint
            .flash_loan(
                borrower,
                shrine.contract_address,
                flash_mint_utils::DEFAULT_MINT_AMOUNT.into(),
                flash_mint_utils::build_calldata(true, flash_borrower_contract::ATTEMPT_TO_STEAL),
            );
    }

    #[test]
    #[should_panic(expected: 'RG: reentrant call')]
    fn test_flash_mint_reenter() {
        let (shrine, flash_mint, borrower) = flash_mint_utils::flash_borrower_setup();
        flash_mint
            .flash_loan(
                borrower,
                shrine.contract_address,
                flash_mint_utils::DEFAULT_MINT_AMOUNT.into(),
                flash_mint_utils::build_calldata(true, flash_borrower_contract::ATTEMPT_TO_REENTER),
            );
    }
}

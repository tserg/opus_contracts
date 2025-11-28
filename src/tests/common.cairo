use access_control::{IAccessControlDispatcher, IAccessControlDispatcherTrait};
use core::num::traits::{Bounded, Pow, Zero};
use opus::constants::{DAI_DECIMALS, LUSD_DECIMALS, USDC_DECIMALS, USDT_DECIMALS};
use opus::core::shrine::shrine;
use opus::interfaces::IAbbot::{IAbbotDispatcher, IAbbotDispatcherTrait};
use opus::interfaces::IERC20::{IERC20Dispatcher, IERC20DispatcherTrait, IMintableDispatcher, IMintableDispatcherTrait};
use opus::interfaces::IGate::{IGateDispatcher, IGateDispatcherTrait};
use opus::interfaces::IShrine::{IShrineDispatcher, IShrineDispatcherTrait};
use opus::mock::erc4626_mintable::{IMockERC4626Dispatcher, IMockERC4626DispatcherTrait};
use opus::mock::mock_ekubo_oracle_extension::IMockEkuboOracleExtensionDispatcher;
use opus::types::{AssetBalance, Reward};
use snforge_std::{
    CheatSpan, ContractClass, ContractClassTrait, DeclareResultTrait, Event, cheat_caller_address, declare,
    start_cheat_block_timestamp_global, start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress, get_block_timestamp};
use wadray::{RAY_PERCENT, Ray, WAD_ONE, Wad};

//
// Types
//

#[derive(Copy, Drop, PartialEq)]
pub enum RecoveryModeSetupType {
    BeforeRecoveryMode,
    BufferLowerBound,
    BufferUpperBound,
    ExceedsBuffer,
}

#[derive(Copy, Drop)]
pub struct YangParams {
    pub address: ContractAddress,
    pub threshold: u128,
    pub base_rate: u128,
    pub start_price: u128,
}

// Trove constants
pub const TROVE_1: u64 = 1;
pub const TROVE_2: u64 = 2;
pub const TROVE_3: u64 = 3;
pub const WHALE_TROVE: u64 = 0xb17b01;


//
// Test addresses
//

pub const BAD_GUY: ContractAddress = 'bad guy'.try_into().unwrap();

// Access control addresses
pub const ADMIN: ContractAddress = 'admin'.try_into().unwrap();
pub const SHRINE_ADMIN: ContractAddress = 'shrine admin'.try_into().unwrap();
pub const SENTINEL_ADMIN: ContractAddress = 'sentinel admin'.try_into().unwrap();
pub const CONTROLLER_ADMIN: ContractAddress = 'controller admin'.try_into().unwrap();
pub const TRANSMUTER_ADMIN: ContractAddress = 'transmuter admin'.try_into().unwrap();
pub const SEER_ADMIN: ContractAddress = 'seer owner'.try_into().unwrap();
pub const CARETAKER_ADMIN: ContractAddress = 'caretaker admin'.try_into().unwrap();
pub const ABSORBER_ADMIN: ContractAddress = 'absorber owner'.try_into().unwrap();
pub const PURGER_ADMIN: ContractAddress = 'purger owner'.try_into().unwrap();
pub const PRAGMA_ADMIN: ContractAddress = 'pragma owner'.try_into().unwrap();
pub const EKUBO_ADMIN: ContractAddress = 'ekubo owner'.try_into().unwrap();

// Mock contract addresses
pub const MOCK_ABBOT: ContractAddress = 'mock abbot'.try_into().unwrap();
pub const MOCK_ABSORBER: ContractAddress = 'mock absorber'.try_into().unwrap();
pub const MOCK_STABILIZER: ContractAddress = 'mock stabilizer'.try_into().unwrap();
pub const MOCK_PURGER: ContractAddress = 'mock purger'.try_into().unwrap();
pub const MOCK_SENTINEL: ContractAddress = 'mock sentinel'.try_into().unwrap();
pub const MOCK_ORACLE_EXTENSION: ContractAddress = 'mock oracle extension'.try_into().unwrap();

// Trove owner addresses
pub const TROVE1_OWNER_ADDR: ContractAddress = 'trove1 owner'.try_into().unwrap();
pub const TROVE2_OWNER_ADDR: ContractAddress = 'trove2 owner'.try_into().unwrap();
pub const TROVE3_OWNER_ADDR: ContractAddress = 'trove3 owner'.try_into().unwrap();
pub const NON_ZERO_ADDR: ContractAddress = 'nonzero address'.try_into().unwrap();

// Yang token addresses
pub const YANG1_ADDR: ContractAddress = 'yang 1'.try_into().unwrap();
pub const YANG2_ADDR: ContractAddress = 'yang 2'.try_into().unwrap();
pub const YANG3_ADDR: ContractAddress = 'yang 3'.try_into().unwrap();

pub const DUMMY_YANG_ADDR: ContractAddress = 'dummy yang'.try_into().unwrap();
pub const DUMMY_YANG_GATE_ADDR: ContractAddress = 'dummy yang token'.try_into().unwrap();

pub const TWO_YANG_ADDRS: [ContractAddress; 2] = [YANG1_ADDR, YANG2_ADDR];
pub const THREE_YANG_ADDRS: [ContractAddress; 3] = [YANG1_ADDR, YANG2_ADDR, YANG3_ADDR];

//
// Yang Parameters
//

pub const YANG1_THRESHOLD: u128 = 80 * RAY_PERCENT; // 80% (Ray)
pub const YANG1_START_PRICE: u128 = 2000 * WAD_ONE; // 2_000 (Wad)
pub const YANG1_BASE_RATE: u128 = 2 * RAY_PERCENT; // 2% (Ray)

pub const YANG2_THRESHOLD: u128 = 75 * RAY_PERCENT; // 75% (Ray)
pub const YANG2_START_PRICE: u128 = 500 * WAD_ONE; // 500 (Wad)
pub const YANG2_BASE_RATE: u128 = 3 * RAY_PERCENT; // 3% (Ray)

pub const YANG3_THRESHOLD: u128 = 85 * RAY_PERCENT; // 85% (Ray)
pub const YANG3_START_PRICE: u128 = 1000 * WAD_ONE; // 1_000 (Wad)
pub const YANG3_BASE_RATE: u128 = (2 * RAY_PERCENT) + (RAY_PERCENT / 2); // 2.5% (Ray)

//
// Yang Parameters Structs
//

pub const YANG1_PARAMS: YangParams = YangParams {
    address: YANG1_ADDR, threshold: YANG1_THRESHOLD, base_rate: YANG1_BASE_RATE, start_price: YANG1_START_PRICE,
};

pub const YANG2_PARAMS: YangParams = YangParams {
    address: YANG2_ADDR, threshold: YANG2_THRESHOLD, base_rate: YANG2_BASE_RATE, start_price: YANG2_START_PRICE,
};

pub const YANG3_PARAMS: YangParams = YangParams {
    address: YANG3_ADDR, threshold: YANG3_THRESHOLD, base_rate: YANG3_BASE_RATE, start_price: YANG3_START_PRICE,
};

pub const TWO_YANG_PARAMS: [YangParams; 2] = [YANG1_PARAMS, YANG2_PARAMS];
pub const THREE_YANG_PARAMS: [YangParams; 3] = [YANG1_PARAMS, YANG2_PARAMS, YANG3_PARAMS];

//
// Standard Asset Amounts
//

// ETH-specific amounts (18 decimals)
pub const SMALL_ETH_DEPOSIT: u128 = 2 * WAD_ONE;
pub const MEDIUM_ETH_DEPOSIT: u128 = 10 * WAD_ONE;
pub const LARGE_ETH_DEPOSIT: u128 = 50 * WAD_ONE;

// WBTC-specific amounts (accounting for 8 decimals)
pub const MEDIUM_WBTC_DEPOSIT: u128 = 50000000; // 0.5 WBTC
pub const LARGE_WBTC_DEPOSIT: u128 = 500000000; // 5 WBTC

pub const LARGE_DEPOSITS: [u128; 2] = [LARGE_ETH_DEPOSIT, LARGE_WBTC_DEPOSIT];

// Common forge amounts
pub const MEDIUM_FORGE: u128 = 3000 * WAD_ONE;
pub const LARGE_FORGE: u128 = 10000 * WAD_ONE;

//
// Trait implementations
//

pub impl RewardPartialEq of PartialEq<Reward> {
    fn eq(mut lhs: @Reward, mut rhs: @Reward) -> bool {
        lhs.asset == rhs.asset
            && lhs.blesser.contract_address == rhs.blesser.contract_address
            && lhs.is_active == rhs.is_active
    }

    fn ne(lhs: @Reward, rhs: @Reward) -> bool {
        !(lhs == rhs)
    }
}

//
// Convenience wrappers
//

#[inline(always)]
pub fn erc20(token: ContractAddress) -> IERC20Dispatcher {
    IERC20Dispatcher { contract_address: token }
}

//
// Helpers - Test setup
//

// Mock Ekubo deployment helper

pub fn declare_mock_ekubo_oracle_extension() -> ContractClass {
    *declare("mock_ekubo_oracle_extension").unwrap().contract_class()
}

pub fn mock_ekubo_oracle_extension_deploy(
    mock_ekubo_oracle_extension_class: Option<ContractClass>,
) -> IMockEkuboOracleExtensionDispatcher {
    let mut calldata: Array<felt252> = ArrayTrait::new();

    let mock_ekubo_oracle_extension_class = mock_ekubo_oracle_extension_class
        .unwrap_or(declare_mock_ekubo_oracle_extension());

    let (mock_ekubo_oracle_extension_addr, _) = mock_ekubo_oracle_extension_class
        .deploy(@calldata)
        .expect('mock ekubo deploy failed');

    IMockEkuboOracleExtensionDispatcher { contract_address: mock_ekubo_oracle_extension_addr }
}

// Helper function to advance timestamp by the given intervals
pub fn advance_intervals_and_refresh_prices_and_multiplier(
    shrine: IShrineDispatcher, yangs: Span<ContractAddress>, intervals: u64,
) {
    // Getting the yang price and interval so that they can be updated after the warp to reduce recursion
    let (current_multiplier, _, _) = shrine.get_current_multiplier();

    let mut yang_prices = array![];

    for yang in yangs {
        let (current_yang_price, _, _) = shrine.get_current_yang_price(*yang);
        yang_prices.append(current_yang_price);
    }

    start_cheat_block_timestamp_global(get_block_timestamp() + (intervals * shrine::TIME_INTERVAL));

    // Updating prices and multiplier
    start_cheat_caller_address(shrine.contract_address, SHRINE_ADMIN);
    shrine.set_multiplier(current_multiplier);
    for yang in yangs {
        let yang_price = yang_prices.pop_front().unwrap();
        shrine.advance(*yang, yang_price);
    }
    stop_cheat_caller_address(shrine.contract_address);
}

#[inline(always)]
pub fn advance_intervals(intervals: u64) {
    start_cheat_block_timestamp_global(get_block_timestamp() + (intervals * shrine::TIME_INTERVAL));
}


// Mock tokens

pub const ETH_TOTAL_SUPPLY: u128 = 100 * WAD_ONE; // 100 (Wad)
pub const WBTC_TOTAL_SUPPLY: u128 = 30 * WAD_ONE; // 30 (Wad)

pub fn eth_token_deploy(token_class: Option<ContractClass>) -> ContractAddress {
    deploy_token('Ether', 'ETH', 18, ETH_TOTAL_SUPPLY.into(), SENTINEL_ADMIN, token_class)
}

pub fn wbtc_token_deploy(token_class: Option<ContractClass>) -> ContractAddress {
    deploy_token('Bitcoin', 'WBTC', 8, WBTC_TOTAL_SUPPLY.into(), SENTINEL_ADMIN, token_class)
}

pub fn usdc_token_deploy(token_class: Option<ContractClass>) -> ContractAddress {
    deploy_token('USD Coin', 'USDC', USDC_DECIMALS.into(), WAD_ONE.into(), ADMIN, token_class)
}

pub fn usdt_token_deploy(token_class: Option<ContractClass>) -> ContractAddress {
    deploy_token('Tether USD', 'USDT', USDT_DECIMALS.into(), WAD_ONE.into(), ADMIN, token_class)
}

pub fn dai_token_deploy(token_class: Option<ContractClass>) -> ContractAddress {
    deploy_token('Dai Stablecoin', 'DAI', DAI_DECIMALS.into(), WAD_ONE.into(), ADMIN, token_class)
}

pub fn lusd_token_deploy(token_class: Option<ContractClass>) -> ContractAddress {
    deploy_token('LUSD Stablecoin', 'LUSD', LUSD_DECIMALS.into(), WAD_ONE.into(), ADMIN, token_class)
}

pub fn quote_tokens(token_class: Option<ContractClass>) -> Span<ContractAddress> {
    let token_class = token_class.unwrap_or(declare_token());
    array![
        dai_token_deploy(Option::Some(token_class)),
        usdc_token_deploy(Option::Some(token_class)),
        usdt_token_deploy(Option::Some(token_class)),
    ]
        .span()
}

pub fn eth_vault_deploy(vault_class: Option<ContractClass>, eth: ContractAddress) -> ContractAddress {
    deploy_vault('Ether Vault', 'vETH', 18, ETH_TOTAL_SUPPLY.into(), SENTINEL_ADMIN, eth, vault_class)
}

pub fn wbtc_vault_deploy(vault_class: Option<ContractClass>, wbtc: ContractAddress) -> ContractAddress {
    deploy_vault('Bitcoin Vault', 'vWBTC', 18, WBTC_TOTAL_SUPPLY.into(), SENTINEL_ADMIN, wbtc, vault_class)
}

pub fn declare_token() -> ContractClass {
    *declare("erc20_mintable").unwrap().contract_class()
}

// Helper function to deploy a token
pub fn deploy_token(
    name: felt252,
    symbol: felt252,
    decimals: felt252,
    initial_supply: u256,
    recipient: ContractAddress,
    token_class: Option<ContractClass>,
) -> ContractAddress {
    let calldata: Array<felt252> = array![
        name,
        symbol,
        decimals,
        initial_supply.low.into(), // u256.low
        initial_supply.high.into(), // u256.high
        recipient.into(),
    ];

    let token_class = token_class.unwrap_or(declare_token());

    let (token_addr, _) = token_class.deploy(@calldata).expect('erc20 deploy failed');
    token_addr
}

// Helper function to deploy a ERC-4626 vault
pub fn deploy_vault(
    name: felt252,
    symbol: felt252,
    decimals: felt252,
    initial_supply: u256,
    recipient: ContractAddress,
    asset: ContractAddress,
    vault_class: Option<ContractClass>,
) -> ContractAddress {
    let calldata: Array<felt252> = array![
        name,
        symbol,
        decimals,
        initial_supply.low.into(), // u256.low
        initial_supply.high.into(), // u256.high
        recipient.into(),
        asset.into(),
    ];

    let vault_class = vault_class.unwrap_or(*declare("erc4626_mintable").unwrap().contract_class());

    let (vault_addr, _) = vault_class.deploy(@calldata).expect('erc4626 deploy failed');

    // Mock initial conversion rate of 1 : 1
    IMockERC4626Dispatcher { contract_address: vault_addr }
        .set_convert_to_assets_per_wad_scale(10_u128.pow(erc20(asset).decimals().into()).into());

    vault_addr
}

#[inline(always)]
pub fn approve_gate_for_token(gate: IGateDispatcher, token: IERC20Dispatcher, user: ContractAddress) {
    // user no-limit approves gate to handle their share of token
    cheat_caller_address(token.contract_address, user, CheatSpan::TargetCalls(1));
    token.approve(gate.contract_address, Bounded::MAX);
}

// Helper function to fund a user account with yang assets
pub fn fund_user(user: ContractAddress, yangs: Span<ContractAddress>, mut asset_amts: Span<u128>) {
    for yang in yangs {
        let amt = *asset_amts.pop_front().unwrap();
        if amt.is_zero() {
            continue;
        }
        IMintableDispatcher { contract_address: *yang }.mint(user, amt.into());
    };
}

// Helper function to approve Gates to transfer tokens from user, and to open a trove
pub fn open_trove_helper(
    abbot: IAbbotDispatcher,
    user: ContractAddress,
    yangs: Span<ContractAddress>,
    yang_asset_amts: Span<u128>,
    mut gates: Span<IGateDispatcher>,
    forge_amt: Wad,
) -> u64 {
    for yang in yangs {
        // Approve Gate to transfer from user
        let gate: IGateDispatcher = *gates.pop_front().unwrap();
        approve_gate_for_token(gate, erc20(*yang), user);
    }

    cheat_caller_address(abbot.contract_address, user, CheatSpan::TargetCalls(1));
    let yang_assets: Span<AssetBalance> = combine_assets_and_amts(yangs, yang_asset_amts);
    let trove_id: u64 = abbot.open_trove(yang_assets, forge_amt, 1_u128.into());

    trove_id
}


// Helpers - Convenience getters

// Helper function to return an array of token balances for an address given a list of
// token addresses
pub fn get_token_balances(tokens: Span<ContractAddress>, address: ContractAddress) -> Span<u128> {
    let mut balances: Array<u128> = ArrayTrait::new();

    for token in tokens {
        let bal: u128 = erc20(*token).balance_of(address).try_into().unwrap();
        balances.append(bal);
    }

    balances.span()
}

// Fetches the ERC20 asset balance of a given address, and
// converts it to yang units.
#[inline(always)]
pub fn get_erc20_bal_as_yang(gate: IGateDispatcher, asset: ContractAddress, owner: ContractAddress) -> Wad {
    gate.convert_to_yang(erc20(asset).balance_of(owner).try_into().unwrap())
}

//
// Helpers - Assertions
//

pub fn assert_equalish<T, impl TPartialOrd: PartialOrd<T>, impl TSub: Sub<T>, impl TCopy: Copy<T>, impl TDrop: Drop<T>>(
    a: T, b: T, error: T, message: felt252,
) {
    if a >= b {
        assert(a - b <= error, message);
    } else {
        assert(b - a <= error, message);
    }
}

pub fn assert_asset_balances_equalish(a: Span<AssetBalance>, mut b: Span<AssetBalance>, error: u128, message: felt252) {
    assert(a.len() == b.len(), message);

    for i in a {
        let b: AssetBalance = *b.pop_front().unwrap();
        assert(*i.address == b.address, 'wrong asset address');
        assert_equalish(*i.amount, b.amount, error, message);
    }
}

// Helper to assert that an event was not emitted at all by checking the event name only
// without checking specific values of the event's members
pub fn assert_event_not_emitted_by_name(emitted_events: Span<(ContractAddress, Event)>, event_selector: felt252) {
    let end_idx = emitted_events.len();
    let mut current_idx = 0;
    while current_idx != end_idx {
        let (_, raw_event) = emitted_events.at(current_idx);

        assert(*raw_event.keys.at(0) != event_selector, 'event name emitted');

        current_idx += 1;
    };
}

//
// Helpers - Array functions
//

pub fn combine_assets_and_amts(assets: Span<ContractAddress>, mut amts: Span<u128>) -> Span<AssetBalance> {
    assert(assets.len() == amts.len(), 'combining diff array lengths');
    let mut asset_balances: Array<AssetBalance> = ArrayTrait::new();
    for asset in assets {
        asset_balances.append(AssetBalance { address: *asset, amount: *amts.pop_front().unwrap() });
    }

    asset_balances.span()
}

// Helper function to multiply an array of values by a given percentage
pub fn scale_span_by_pct(asset_amts: Span<u128>, pct: Ray) -> Span<u128> {
    let mut split_asset_amts: Array<u128> = ArrayTrait::new();
    for asset_amt in asset_amts {
        // Convert to Wad for fixed point operations
        let asset_amt: Wad = (*asset_amt).into();
        split_asset_amts.append(wadray::rmul_wr(asset_amt, pct).into());
    }

    split_asset_amts.span()
}

// Helper function to combine two arrays of equal lengths into a single array by doing element-wise addition.
// Assumes the arrays are ordered identically.
pub fn combine_spans(lhs: Span<u128>, mut rhs: Span<u128>) -> Span<u128> {
    assert(lhs.len() == rhs.len(), 'combining diff array lengths');
    let mut combined_asset_amts: Array<u128> = ArrayTrait::new();

    for asset_amt in lhs {
        // Convert to Wad for fixed point operations
        combined_asset_amts.append(*asset_amt + *rhs.pop_front().unwrap());
    }

    combined_asset_amts.span()
}

// Helper function to grant a role to an address (automatically gets admin)
#[inline(always)]
pub fn grant_role_for_address(contract: ContractAddress, role: u128, address: ContractAddress) {
    let ac = IAccessControlDispatcher { contract_address: contract };
    let admin: ContractAddress = ac.get_admin();
    cheat_caller_address(contract, admin, CheatSpan::TargetCalls(1));
    ac.grant_role(role, address);
}

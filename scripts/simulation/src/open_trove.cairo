use scripts::addresses;
use scripts::constants::MAX_FEE;
use simulation::utils;
use sncast_std::{call, CallResult, invoke, InvokeResult, ScriptCommandError};
use starknet::ContractAddress;
use wadray::WAD_ONE;

fn main() {
    // Approve ETH and STRK
    utils::max_approve_token_for_gate(addresses::eth_addr(), addresses::devnet::eth_gate());
    utils::max_approve_token_for_gate(addresses::strk_addr(), addresses::devnet::strk_gate());

    let open_trove_calldata: Array<felt252> = array![
        2,
        // eth
        addresses::eth_addr().into(),
        // 10 eth (Wad)
        10000000000000000000.into(),
        // strk
        addresses::strk_addr().into(),
        (1000 * WAD_ONE).into(),
        // forge amt
        (2500 * WAD_ONE).into(),
        0,
    ];

    invoke(
        addresses::devnet::abbot(), selector!("open_trove"), open_trove_calldata, Option::Some(MAX_FEE), Option::None
    )
        .expect('open trove failed');

    let call_result = call(addresses::devnet::abbot(), selector!("get_troves_count"), array![])
        .expect('`get_troves_count` failed');
    let trove_id = *call_result.data.at(0);

    println!("Trove opened with ID {}", trove_id);
}

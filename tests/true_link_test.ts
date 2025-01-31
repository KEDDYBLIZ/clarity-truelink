import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Owner can register reviewers",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('true_link', 'register-reviewer', 
        [types.principal(wallet1.address)], deployer.address)
    ]);
    
    assertEquals(block.receipts[0].result.expectOk(), true);
    
    let checkReviewer = chain.mineBlock([
      Tx.contractCall('true_link', 'is-reviewer',
        [types.principal(wallet1.address)], deployer.address)
    ]);
    
    assertEquals(checkReviewer.receipts[0].result.expectOk(), true);
  },
});

Clarinet.test({
  name: "Reviewers can claim rewards after consensus",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    const wallet3 = accounts.get('wallet_3')!;
    
    // Register reviewers
    let setup = chain.mineBlock([
      Tx.contractCall('true_link', 'register-reviewer',
        [types.principal(wallet1.address)], deployer.address),
      Tx.contractCall('true_link', 'register-reviewer',
        [types.principal(wallet2.address)], deployer.address),
      Tx.contractCall('true_link', 'register-reviewer',
        [types.principal(wallet3.address)], deployer.address)
    ]);
    
    // Submit reviews
    let reviews = chain.mineBlock([
      Tx.contractCall('true_link', 'submit-review',
        [
          types.ascii("https://example.com/page"),
          types.ascii("example.com"),
          types.bool(true)
        ],
        wallet1.address),
      Tx.contractCall('true_link', 'submit-review',
        [
          types.ascii("https://example.com/page"),
          types.ascii("example.com"),
          types.bool(true)
        ],
        wallet2.address),
      Tx.contractCall('true_link', 'submit-review',
        [
          types.ascii("https://example.com/page"),
          types.ascii("example.com"),
          types.bool(true)
        ],
        wallet3.address)
    ]);

    // Check consensus
    let consensus = chain.mineBlock([
      Tx.contractCall('true_link', 'get-link-consensus',
        [types.ascii("https://example.com/page")],
        deployer.address)
    ]);

    const consensusResult = consensus.receipts[0].result.expectOk().expectSome();
    assertEquals(consensusResult.consensus, true);
    
    // Claim rewards
    let claim = chain.mineBlock([
      Tx.contractCall('true_link', 'claim-rewards',
        [], wallet1.address)
    ]);
    
    assertEquals(claim.receipts[0].result.expectOk(), types.uint(10));
  },
});

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
  name: "Non-owners cannot register reviewers",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    const wallet2 = accounts.get('wallet_2')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('true_link', 'register-reviewer',
        [types.principal(wallet2.address)], wallet1.address)
    ]);
    
    assertEquals(block.receipts[0].result.expectErr(), types.uint(100));
  },
});

Clarinet.test({
  name: "Reviewers can submit reviews",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // First register a reviewer
    let register = chain.mineBlock([
      Tx.contractCall('true_link', 'register-reviewer',
        [types.principal(wallet1.address)], deployer.address)
    ]);
    
    // Submit a review
    let review = chain.mineBlock([
      Tx.contractCall('true_link', 'submit-review',
        [
          types.ascii("https://example.com/page"),
          types.ascii("example.com"),
          types.bool(true)
        ],
        wallet1.address)
    ]);
    
    assertEquals(review.receipts[0].result.expectOk(), true);
    
    // Check the review
    let checkReview = chain.mineBlock([
      Tx.contractCall('true_link', 'get-review',
        [
          types.ascii("https://example.com/page"),
          types.principal(wallet1.address)
        ],
        deployer.address)
    ]);
    
    const reviewResult = checkReview.receipts[0].result.expectOk();
    assert(reviewResult);
    assertEquals(reviewResult.verdict, true);
  },
});
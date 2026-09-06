/// In-app legal content: Privacy Policy, Terms of Service, and FAQ.
///
/// Values below mirror the live product (0.2% withdrawal fee with ₦10 min /
/// ₦100 cap, ~24h elevation time-lock) and the canonical documents. Contact
/// details follow what the app already publishes.
class LegalDocuments {
  static const supportEmail = 'legal@globemint.app';
  static const lastUpdated = 'September 2026';

  static const List<LegalSection> privacyPolicy = [
    LegalSection('1. Introduction', [
      'Globe Mint is a self-custodial stablecoin savings and payments platform. This policy explains what personal data we collect, why, and what rights you have — in plain language.',
      'Important context: Globe Mint is self-custodial. Your USDC lives in a smart-contract vault on the blockchain that has no owner and no admin — not even us. We never hold your funds and never touch fiat currency. Most of what the law calls "financial data" therefore never passes through our hands at all.',
    ]),
    LegalSection('2. Data we collect', [
      'We deliberately collect as little as possible. There is no KYC and no identity verification.',
      'Account data (you provide it): email address for login, security alerts, and support; password, stored only as a one-way bcrypt hash we cannot see or recover; and a 6-digit transaction PIN, stored only as a hash.',
      'Security data: TOTP two-factor secret (only if you enable 2FA), plus device and session records — login timestamps, device labels, and IP addresses — used to detect suspicious activity and let you review or revoke sessions.',
      'Usage data: on-chain activity linked to your account (deposit addresses, deposit and withdrawal history) which is already public on the blockchain and is indexed so the app can display balances; plus technical logs used to keep the service reliable.',
      'What we do NOT collect: government IDs, selfies, proof of address, bank account details, or card numbers. We have no fiat on- or off-ramp, so we never see your banking information.',
    ]),
    LegalSection('3. How we use your data', [
      'To provide the service: authenticate you, display vault balances and NGN-equivalent values, relay your signed withdrawal requests, and enforce daily limits and time-locks.',
      'For security: detect abnormal logins, throttle repeated failures, and notify you of new devices or sessions.',
      'For support: respond when you contact us.',
      'We do not sell your data, use it for advertising, or build marketing profiles.',
    ]),
    LegalSection('4. Data retention', [
      'Active accounts: we keep your account, ledger, and security records while your account exists — the app cannot function without them.',
      'Closed accounts: on request we delete or anonymize your data, except records we must keep for legal, security, or audit reasons.',
      'Blockchain data is permanent and public by design. We cannot delete anything from the blockchain.',
    ]),
    LegalSection('5. Security', [
      'We protect your data with bcrypt password hashing, hashed PINs, optional TOTP two-factor authentication, login and PIN throttling, encrypted connections, and restricted internal access.',
      'No system is perfectly secure, and the most important factor is you: use a strong unique password, enable 2FA, keep your email secure, and never share your PIN. Anyone with your login credentials and PIN can initiate withdrawals.',
    ]),
    LegalSection('6. Third parties', [
      'Blockchain networks (Ethereum, Base, Arbitrum, Optimism, Sepolia and testnets): your wallet addresses and transactions are visible to anyone, as with all public blockchains.',
      'Infrastructure providers (hosting, node/RPC providers) process data only to deliver the service under contractual confidentiality.',
      'Authorities: we disclose data only when required by valid applicable law.',
      'We use no third-party advertising or cross-site tracking tools.',
    ]),
    LegalSection('7. Your rights', [
      'Subject to applicable law, you may request a copy of the data we hold about you, correct inaccurate data, request deletion of your account and associated data, and review or revoke sessions and devices at any time in the app. Contact $supportEmail for any of these.',
    ]),
    LegalSection('8. Children', [
      'Globe Mint is not directed at children. You must be at least 18 years old (or the age of majority where you live) to use the service.',
    ]),
    LegalSection('9. Changes to this policy', [
      'Material changes will be posted with a new "Last updated" date and, where appropriate, announced in the app or by email. Continued use after the changes take effect means you accept them.',
    ]),
  ];

  static const List<LegalSection> termsOfService = [
    LegalSection('1. The service', [
      'Globe Mint is a self-custodial stablecoin savings and payments platform. It lets you deposit USDC from your own Ethereum wallet into a smart-contract vault, view your balance with an NGN-equivalent display value, and withdraw USDC to any address you specify, confirmed with your 6-digit PIN. Larger withdrawals pass through a cancellable time-lock. The backend relays your signed withdrawal requests and keeps an NGN display ledger. It never takes custody of funds.',
    ]),
    LegalSection('2. Self-custody and risk', [
      'You are always in control of your funds — which means you also carry the responsibilities of control.',
      'No owner, no admin, no recovery. The vault contract has no owner and no administrator: nobody, including us, can seize, freeze, move, or recover your USDC. There is no "forgot funds" button.',
      'Blockchain transactions are irreversible. A withdrawal sent to the wrong address cannot be undone by us or anyone else. Always double-check destination addresses.',
      'Your wallet, your keys. Deposits come from your own wallet (MetaMask, WalletConnect, or similar). If you lose access to that wallet, we cannot recover it for you.',
      'Stablecoin risk. USDC is issued by Circle, a private company — not by Globe Mint. It aims to track US\$1 but can depeg or face redemption problems in stressed markets.',
      'Network risk. Blockchains can congest, reorganize, or halt. Deposits credit only after a confirmation window; withdrawals depend on the network accepting the broadcast.',
      'Gas fees. You pay network gas for your own deposit transactions. Gas on Ethereum mainnet can be significant — Layer 2 networks (Base, Arbitrum, Optimism) are recommended.',
      'Display values are not guarantees. NGN equivalents are convenience conversions at the current rate, not a promise of redemption value.',
    ]),
    LegalSection('3. Eligibility', [
      'You must be at least 18 (or the age of majority where you live) and legally able to use crypto-asset software in your location. You are responsible for determining whether using Globe Mint is lawful for you, including any tax obligations on your activity.',
    ]),
    LegalSection('4. Your account and its security', [
      'Only an email and password are required; there is no identity verification. You are responsible for everything done through your account: keep your password, PIN, email account, and personal wallet secure, and enable 2FA.',
      'Tell us immediately at $supportEmail if you suspect unauthorized access. We can help you revoke sessions and review activity — but we cannot reverse on-chain transfers.',
    ]),
    LegalSection('5. Fees', [
      'Deposits are free. We charge nothing; you pay only your own network gas.',
      'Withdrawals carry a platform fee of 0.2% of the NGN-equivalent amount, minimum ₦10, maximum ₦100. The fee covers operational costs and the gas for the withdrawal broadcast. It is deducted in NGN on top of your withdrawal amount; only the principal is converted and sent.',
      'Cancelled time-locked withdrawals incur no fee.',
      'Conversions between NGN and stablecoins, where offered, may carry a separate fee shown in the quote (e.g. 0.5%).',
      'Fees may change with notice. The fee actually charged is always the server-side computed figure, not any client-side preview.',
    ]),
    LegalSection('6. Withdrawal limits and time-locks', [
      'Withdrawals may be subject to per-transaction minimum/maximum amounts and a daily cap, all enforced automatically.',
      'Withdrawals above the safety threshold enter a time-lock (usually 24 hours) before broadcast. You may cancel at any time during the window at no cost; after release the broadcast proceeds and cannot be stopped.',
      'A request that would exceed your balance (principal + fee) is rejected before anything is broadcast, so failed requests never cost you gas.',
    ]),
    LegalSection('7. Prohibited activities', [
      'You agree not to use the service for money laundering, fraud, sanctions evasion, or any unlawful purpose; not to attack, probe, or degrade the platform (including circumventing rate limits, PIN throttling, or withdrawal caps); not to submit false information to support; and not to copy, reverse-engineer, or redistribute our proprietary backend or frontend code. The smart-contract code is public by nature of being on-chain; everything else is ours.',
    ]),
    LegalSection('8. Intellectual property', [
      'The Globe Mint name, branding, backend, and frontend are proprietary. The vault smart contract is deployed on public blockchains and its bytecode is inherently visible; no license to our off-chain software is granted except the right to use the service normally.',
    ]),
    LegalSection('9. Disclaimers', [
      'The service is provided "as is" and "as available", without warranties of any kind — including availability, accuracy of display values or quotes, uninterrupted operation, or fitness for a particular purpose. We do not promise any return, yield, or interest: Globe Mint is a savings rails product, not an investment.',
    ]),
    LegalSection('10. Limitation of liability', [
      'To the maximum extent permitted by applicable law, we are not liable for losses arising from blockchain behavior, stablecoin depegging or issuer actions, gas costs, your lost credentials or compromised devices, your addressing mistakes, or third-party wallets and networks.',
    ]),
    LegalSection('11. Indemnification', [
      'You agree to indemnify and hold harmless Globe Mint, its team, and service providers against claims, losses, and expenses arising from your misuse of the service, your violation of these terms, or your violation of any law.',
    ]),
    LegalSection('12. Termination', [
      'You may stop using Globe Mint at any time — withdraw your funds and close your account. We may suspend or terminate accounts that violate these terms, abuse the platform, or where required by law. Termination never affects USDC already in the vault contract: because it has no admin, your on-chain funds remain accessible to whoever controls the depositing wallet regardless of your account status.',
    ]),
    LegalSection('13. Governing law and disputes', [
      'These terms are governed by applicable law. Disputes should first be raised with $supportEmail; we will attempt good-faith resolution before either party pursues formal remedies.',
    ]),
    LegalSection('14. Changes to these terms', [
      'We may update these terms (e.g. when fees, limits, or supported networks change). Material changes will be posted with a new date and, where appropriate, announced in-app or by email. Continued use constitutes acceptance. If you disagree, your remedy is to withdraw your funds and stop using the service.',
    ]),
  ];

  static const List<FaqEntry> faq = [
    FaqEntry(
      'What is Globe Mint?',
      'A savings and payments app built on USDC, a dollar-pegged stablecoin. You deposit USDC into a smart-contract vault, see its value in naira, and withdraw to any crypto address whenever you like — a dollar-denominated savings jar that lives on the blockchain instead of in a bank.',
    ),
    FaqEntry(
      'Is Globe Mint a bank? Is my money insured?',
      'No to both. Globe Mint is not a bank, holds no banking license, and offers no deposit insurance or guaranteed returns. Your USDC sits in a smart contract, not in any company account.',
    ),
    FaqEntry(
      'What does "self-custodial" mean for me?',
      'No one — not even us — can touch, freeze, or move your funds. The vault contract has no owner and no admin keys. The flip side: there is no password-reset for the blockchain. You are your own bank, with all the freedom and responsibility that implies.',
    ),
    FaqEntry(
      'How is this different from keeping money on an exchange?',
      'On an exchange, the company holds your coins and can freeze withdrawals, get hacked, or go insolvent with your money inside. With Globe Mint, the platform only relays your instructions; the funds rest in a contract that answers to the blockchain alone.',
    ),
    FaqEntry(
      'Do I need KYC or ID verification?',
      'No. You sign up with just an email and password. There is no ID upload, selfie, or proof of address — because we never hold your money or touch fiat, there is nothing to verify you against.',
    ),
    FaqEntry(
      'What does it cost?',
      'Deposits are free — you only pay your own network gas. Withdrawals cost 0.2%, minimum ₦10, maximum ₦100, deducted in naira on top of your withdrawal. Withdrawing ₦50,000 costs ₦100; withdrawing ₦5,000 costs ₦10. The review screen shows the exact fee, the total charged, and the USDC you will receive before you confirm.',
    ),
    FaqEntry(
      'What is "gas" and how do I keep it cheap?',
      'Gas is the network fee paid to blockchain validators. You pay gas on your own deposit transaction; we cover the gas for withdrawal broadcasts out of the withdrawal fee. Gas on Ethereum mainnet can be expensive — use Base, Arbitrum, or Optimism (Layer 2 networks), where transactions typically cost a few cents.',
    ),
    FaqEntry(
      'How do withdrawals work, and what is the time-lock?',
      'Enter an amount and a destination address, confirm with your 6-digit PIN, and the platform broadcasts USDC to that address. Larger withdrawals pass through a time-lock of about 24 hours before broadcasting, giving you a window to spot and stop anything suspicious.',
    ),
    FaqEntry(
      'Can I cancel a withdrawal?',
      'Yes — any time during the time-lock window, free of charge, right from the app. Once the window passes and the broadcast goes out, it cannot be reversed by anyone. Small instant withdrawals broadcast immediately and cannot be cancelled, so double-check the address first.',
    ),
    FaqEntry(
      'What happens if I forget my password or PIN?',
      'Your blockchain funds are safe — they live in the vault contract and are reachable from the wallet you deposited with. For the app itself, passwords can be reset via your email, and your PIN can be reset after re-verifying through your email and 2FA (if enabled). Without access to your email, recovery may be impossible.',
    ),
    FaqEntry(
      'What if I lose access to my crypto wallet?',
      'If you can still log in to Globe Mint, withdraw your vault funds to a new wallet address you control (subject to PIN, limits, and any time-lock). If you have lost both, contact $supportEmail — we will help with what we can, but self-custody has hard limits.',
    ),
    FaqEntry(
      'Why should I trust Globe Mint?',
      'You do not have to trust us with your money, because we cannot touch it. What you can verify: the vault contract is on a public blockchain for anyone to inspect, and every deposit and withdrawal is visible on-chain. Trust the code and the chain, not our promises.',
    ),
    FaqEntry(
      'Which networks and wallets are supported?',
      'Ethereum mainnet and Sepolia testnet, plus Layer 2 networks Base, Arbitrum, and Optimism (and their testnets) — L2 is recommended for low gas. Any standard Ethereum wallet works for deposits: MetaMask, WalletConnect-compatible wallets, and similar. Each network has its own separate vault deployment.',
    ),
    FaqEntry(
      'What are the risks of USDC itself?',
      'USDC is issued by Circle, a private company — not by Globe Mint and not by any government. It is designed to stay at US\$1 but is not guaranteed: it can temporarily depeg, and in extreme scenarios Circle or market stress could affect redemption. Only save what you can afford to expose to that risk.',
    ),
    FaqEntry(
      'Can I convert back to naira in my bank account?',
      'Globe Mint has no fiat off-ramp: we never touch naira or bank transfers. To cash out, withdraw USDC to your own wallet and convert it through an exchange or peer-to-peer service of your choice — which will have its own fees and rates. NGN values in the app are display conversions, not redemption promises.',
    ),
    FaqEntry(
      'Is there a mobile app?',
      'Globe Mint runs as a mobile-friendly web app today, with the same features on phone and desktop browsers.',
    ),
    FaqEntry(
      'How do I get started?',
      'Create an account with your email and password (enable 2FA in Profile → Security), set your 6-digit withdrawal PIN, switch your wallet to a low-fee network (Base, Arbitrum, or Optimism), open Top Up, copy your vault deposit address, and send any amount of USDC to it. Your balance appears once the deposit confirms on-chain.',
    ),
  ];
}

/// One numbered section of a legal document.
class LegalSection {
  const LegalSection(this.title, this.paragraphs);
  final String title;
  final List<String> paragraphs;
}

/// One frequently asked question and its answer.
class FaqEntry {
  const FaqEntry(this.question, this.answer);
  final String question;
  final String answer;
}

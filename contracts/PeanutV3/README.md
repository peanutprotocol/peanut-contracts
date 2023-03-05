New features in v0.3

Asymmetric cryptography!

- Benefit one: no need for commit/reveal scheme. Just sign the tx with your private key and send it to the SC. No need to reveal the private key in the link!

- Benefit two: can have gasless transactions that are trustless - frontend w/ link signs tx
    - problem: link is in URL, that _has_ to go to server... we can just not log it, but how to prove it?
    - Solution1: Dapp peanut frontend that's completely decentralized and just stays on IPFS?

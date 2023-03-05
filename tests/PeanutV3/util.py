import hashlib

import web3


def generate_keys_from_string(string: str) -> dict:
    """generates a key pair from an arbitrary length string
    Has same results as Javascript generateKeysFromString()
    """

    str_bytes = string.encode()
    print(str_bytes)
    id = hashlib.sha256(string.encode()).hexdigest()
    private_key = "0x" + id
    w3 = web3.Web3()
    wallet = w3.eth.account.from_key(private_key)

    return {"address": wallet.address, "privateKey": wallet.key.hex()}


def sign_address(address, private_key):
    """signs a standard ethereum address with a private key"""

    assert string.startswith("0x") and len(string) == 42, "String is not an address"

    # ...

    # temp
    assert address == "0x5B38Da6a701c568545dCfcB03FcB875f56beddC4"
    assert private_key == "0xb94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"
    signature = "0xcffbbbc4a538238a7945baffad39d6950fd424a52144bb9beb680ebbc85d7f026274d8449192b49a635d63f2fa886fa0c61f9b9aa920cbd228afb8a34c7cb9711b"
    return signature


if __name__ == "__main__":
    string = "hello world"
    print(generate_keys_from_string(string))

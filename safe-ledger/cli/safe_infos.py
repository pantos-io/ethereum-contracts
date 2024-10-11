import eth_typing
import eth_utils
import gnosis.eth.constants
import gnosis.safe.safe


class SafeInfos(dict[eth_typing.ChecksumAddress, gnosis.safe.safe.SafeInfo]):
    """A dictionary-like class that maps Ethereum checksum addresses to
    SafeInfo objects.

    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    @classmethod
    def parse(cls, safe_info_json: dict) -> 'SafeInfos':
        """Parse a dictionary of safe info JSON objects into a SafeInfos.

        Parameters
        ----------
        safe_info_json : dict
            A dictionary of safe info JSON objects.

        Returns
        -------
        SafeInfos
            Information about the safes.

        """
        instance = cls()
        for address, info in safe_info_json.items():
            safe_address = eth_utils.to_checksum_address(address)
            owners = [
                eth_utils.to_checksum_address(owner)
                for owner in info["owners"]
            ]
            nonce = int(info["nonce"], 16)
            threshold = int(info["threshold"], 16)

            version = "1.4.1"  # FIXME read from json
            safe_info = gnosis.safe.safe.SafeInfo(
                address=safe_address,
                fallback_handler=gnosis.eth.constants.NULL_ADDRESS,
                guard=gnosis.eth.constants.NULL_ADDRESS,
                master_copy=gnosis.eth.constants.NULL_ADDRESS,
                modules=[],
                nonce=nonce,
                owners=owners,
                threshold=threshold,
                version=version)
            instance[safe_address] = safe_info
        return instance

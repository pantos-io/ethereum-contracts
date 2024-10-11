import eth_typing
import eth_utils
import gnosis
import gnosis.safe

from safe_infos import SafeInfos


class DummyEthereumClient(gnosis.eth.EthereumClient):
    """Dummy Ethereum client for testing purposes.

    """

    def __init__(self):
        super().__init__(ethereum_node_url=eth_typing.URI(""))


class SafeTxBuilder:
    """Responsible for building Safe transactions.

    """

    def __init__(self, safe_infos: SafeInfos):
        """Initialise the SafeTxBuilder.

        Parameters
        ----------
        safe_infos : SafeInfos
            Information about the safes.

        """
        self.safe_infos = safe_infos
        self.signer_and_placeholders = {}
        for safe_address, safe_info in safe_infos.items():
            signer_and_placeholder = []
            for owner in safe_info.owners:
                signer_and_placeholder.append({
                    "signer": owner,
                    "signature": ""
                })

            self.signer_and_placeholders[safe_address] = signer_and_placeholder

    def _fix_nonce(self, transaction: dict,
                   safe_address: eth_typing.ChecksumAddress):
        """Fix the nonce in the transaction.

        Parameters
        ----------
        transaction : dict
            A dictionary containing the transaction data.
        safe_address : ChecksumAddress
            The checksum address of the Safe.

        """
        nonce = self.safe_infos[safe_address].nonce
        transaction["transaction"]["nonce"] = hex(nonce)
        self.safe_infos[safe_address].nonce += 1

    def _add_safe_tx(self, transaction: dict, safe_tx: gnosis.safe.SafeTx):
        """Add the SafeTx eip712_structured_data to the transaction.

        Parameters
        ----------
        transaction : dict
            A dictionary containing the transaction data.
        safe_tx : SafeTx
            The Safe transaction.

        """

        transaction["safeTx"] = safe_tx.eip712_structured_data
        transaction["safeTx"]["message"]["data"] = transaction["safeTx"][
            "message"]["data"].hex()

    def _add_safe_tx_hash(self, transaction: dict,
                          safe_tx: gnosis.safe.SafeTx):
        """Add the SafeTxHash to the transaction.

        Parameters
        ----------
        transaction : dict
            A dictionary containing the transaction data.
        safe_tx : SafeTx
            The Safe transaction.

        """
        # Add the SafeTxHash to the transaction
        transaction["safeTxHash"] = safe_tx.safe_tx_hash.hex()

    def _add_signers(self, transaction: dict,
                     safe_address: eth_typing.ChecksumAddress):
        """Add the signers to the transaction.

        Parameters
        ----------
        transaction : dict
            A dictionary containing the transaction data.
        safe_address : ChecksumAddress
            The checksum address of the Safe.

        """
        signer_and_placeholder = self.signer_and_placeholders[safe_address]
        transaction["signatures"] = signer_and_placeholder

    def _add_threshold(self, transaction: dict,
                       safe_info: gnosis.safe.safe.SafeInfo):
        """Add the threshold to the transaction.

        Parameters
        ----------
        transaction : dict
            A dictionary containing the transaction data.

        """
        transaction["threshold"] = hex(safe_info.threshold)

    def _make_safe_tx(self, transaction: dict,
                      safe_info: gnosis.safe.safe.SafeInfo):
        """Make a SafeTx object from the transaction data.

        Parameters
        ----------
        transaction : dict
            A dictionary containing the transaction data.
        safe_info : SafeInfo
            Information about the Safe.

        Returns
        -------
        SafeTx
            The Safe transaction.

        """
        return gnosis.safe.SafeTx(
            ethereum_client=DummyEthereumClient(),
            safe_address=safe_info.address,
            to=eth_utils.to_checksum_address(transaction["transaction"]["to"]),
            value=int(transaction["transaction"]["value"], 16),
            data=transaction["transaction"]["input"],
            operation=gnosis.safe.SafeOperationEnum.CALL.
            value,  # FIXME check if all tx are call only
            safe_tx_gas=0,
            base_gas=0,
            gas_price=0,
            gas_token=None,
            refund_receiver=None,
            safe_nonce=int(transaction["transaction"]["nonce"], 16),
            safe_version=safe_info.version,
            chain_id=int(transaction["transaction"]["chainId"], 16))

    def _process_transaction(self, transaction: dict):
        """Process a transaction to build the Safe transaction.

        Parameters
        ----------
        transaction : dict
            A dictionary containing the transaction data.

        """
        safe_address = eth_utils.to_checksum_address(
            transaction["transaction"]["from"])

        # Fix nonce first thing
        self._fix_nonce(transaction, safe_address)

        # Now create safe structs for easy appending
        safe_info = self.safe_infos[safe_address]
        safe_tx = self._make_safe_tx(transaction, safe_info)

        # Append
        self._add_safe_tx(transaction, safe_tx)
        self._add_safe_tx_hash(transaction, safe_tx)
        self._add_signers(transaction, safe_address)
        self._add_threshold(transaction, safe_info)

    def extend_transactions(self, input_json: dict):
        """Extend the transactions with SafeTx data.

        Parameters
        ----------
        input_json : dict
            A dictionary containing the transaction data.

        """
        for transaction in input_json.get("transactions", []):
            self._process_transaction(transaction)

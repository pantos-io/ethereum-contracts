import gnosis.safe.safe_signature
import hexbytes


class SafeSigCollator:
    """Responsible for collating signatures for Safe transactions.

    """

    def _parse_safe_signatures(
            self, transaction: dict) \
            -> list[gnosis.safe.safe_signature.SafeSignatureEOA]:
        """Parse the Safe signatures from a transaction.

        Parameters
        ----------
        transaction : dict
            A dictionary containing the transaction data.

        Returns
        -------
        list of SafeSignatureEOA
            The Safe signatures provided by the EOA owners.

        """
        safe_tx_hash = transaction["safeTxHash"]
        signatures_json = transaction.get("signatures", [])

        signatures = []
        for detail in signatures_json:
            signature = detail.get('signature', '')
            if signature:
                signatures.append(
                    gnosis.safe.safe_signature.SafeSignatureEOA(
                        signature, safe_tx_hash))
        return signatures

    def _add_collated_signature(
            self, transaction: dict,
            signatures: list[gnosis.safe.safe_signature.SafeSignatureEOA]):
        """Add the collated signature to the transaction.

        Parameters
        ----------
        transaction : dict
            A dictionary containing the transaction data.
        signatures : list of SafeSignatureEOA
            The Safe signatures provided by the EOA owners.

        """
        collated = \
            gnosis.safe.safe_signature.SafeSignatureEOA.export_signatures(
                signatures)
        transaction["collated-signature"] = hexbytes.HexBytes(collated).hex()

    def _process_transaction(self, transaction: dict):
        """Process a transaction to collate the signatures.

        Parameters
        ----------
        transaction : dict
            A dictionary containing the transaction data.

        """
        threshold = int(transaction["threshold"], 16)
        signatures = self._parse_safe_signatures(transaction)
        if len(signatures) >= threshold:
            self._add_collated_signature(transaction, signatures)

    def collate_signatures(self, input_json: dict):
        """Collate the signatures for the Safe transactions.

        Parameters
        ----------
        input_json : dict
            A dictionary containing the transaction data.

        """
        for transaction in input_json.get("transactions", []):
            self._process_transaction(transaction)

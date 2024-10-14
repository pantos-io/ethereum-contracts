class SafeTxFlattener:
    """Responsible for flattening Safe transactions.

    """

    def _flatten_transaction(self, transaction):
        """Flatten a transaction.

        Parameters
        ----------
        transaction : dict
            A dictionary containing the transaction data.

        Returns
        -------
        dict
            The flattened transaction.

        """
        return {
            "chainId": int(transaction["transaction"]["chainId"], 16),
            "data": transaction["transaction"]["input"],
            "from": transaction["transaction"]["from"],
            "signatures": transaction["collated-signature"],
            "to": transaction["transaction"]["to"],
            "value": int(transaction["transaction"]["value"], 16),
        }

    def flatten_transactions(self, input_json: dict) -> list[dict]:
        """Flatten the transactions.

        Parameters
        ----------
        input_json : dict
            A dictionary containing the transaction data.

        Returns
        -------
        list of dict
            The flattened transactions.

        """
        flattened_transactions = []
        for transaction in input_json.get("transactions", []):
            flattened_transactions.append(
                self._flatten_transaction(transaction))
        return flattened_transactions

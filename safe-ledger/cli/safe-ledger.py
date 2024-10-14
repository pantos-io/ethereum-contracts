import argparse
import json
import pathlib
import sys

from safe_infos import SafeInfos
from safe_sig_collator import SafeSigCollator
from safe_tx_builder import SafeTxBuilder
from safe_tx_flattener import SafeTxFlattener


def read_json(input_json_file: pathlib.Path) -> dict:
    """Read a JSON file and return the content as a dictionary.

    Parameters
    ----------
    input_json_file : pathlib.Path
        The path to the input JSON file.

    Returns
    -------
    dict
        The content of the input JSON file.

    """
    # Check if the input file exist
    if not (input_json_file and input_json_file.exists()):
        raise FileNotFoundError(
            f"Error: File {input_json_file} does not exist.")
    # Load the input JSON file
    with input_json_file.open('r') as file:
        json_dict = json.load(file)
    return json_dict


def _execute_command_extend(arguments: argparse.Namespace):
    """Execute the extend command.

    Parameters
    ----------
    arguments : argparse.Namespace
        The command line arguments.

    """
    # Load the input JSON files
    tx_json = read_json(arguments.input)
    safe_info = read_json(arguments.safe_info)

    safe_infos = SafeInfos.parse(safe_info)

    safe_tx_builder = SafeTxBuilder(safe_infos)
    safe_tx_builder.extend_transactions(tx_json)

    # Save the output JSON to the specified output file
    with arguments.output.open('w') as file:
        json.dump(tx_json, file, indent=2)

    print(f"Output saved to {arguments.output}")


def _execute_command_collate(arguments: argparse.Namespace):
    """Execute the collate command.

    Parameters
    ----------
    arguments : argparse.Namespace
        The command line arguments.

    """
    # Check if the input file exist
    if not (arguments.input and arguments.input.exists()):
        print(f"Error: Input file {arguments.input} does not exist.")
        return

    # Load the input JSON file
    tx_json = read_json(arguments.input)

    safe_sig_collator = SafeSigCollator()
    safe_sig_collator.collate_signatures(tx_json)

    safe_tx_flattener = SafeTxFlattener()
    flattened_transactions = safe_tx_flattener.flatten_transactions(tx_json)

    # Save the output JSON to the specified output file
    with arguments.output.open('w') as file:
        json.dump(tx_json, file, indent=2)

    print(f"Output saved to {arguments.output}")

    # Save the output JSON to the specified output file
    with arguments.flat_output.open('w') as file:
        json.dump(flattened_transactions, file, indent=2)

    print(f"Flat output saved to {arguments.flat_output}")


def _create_argument_parser() -> argparse.ArgumentParser:
    """Create the argument parser.

    Returns
    -------
    argparse.ArgumentParser
        The argument parser.

    """
    # Show help if no argument is given
    if len(sys.argv) == 1:
        sys.argv.append('--help')
    # Set up the argument parser
    parser = argparse.ArgumentParser(
        prog='safe-ledger',
        description='Utility for extending foundry broadcast simulation to'
        ' work with safe multi-sig wallet and Ledger')
    subparsers = parser.add_subparsers(dest='command')

    # Argument parser for extending foundry broadcast
    parser_extend = subparsers.add_parser(
        'extend', help='extend broadcast simulation with safe tx info')
    parser_extend.add_argument(
        '-i',
        '--input',
        type=pathlib.Path,
        help='path to foundry generated broadcast simulation JSON file ')

    parser_extend.add_argument(
        '-s',
        '--safe-info',
        type=pathlib.Path,
        help='path to all the safe information JSON file ')

    parser_extend.add_argument(
        '-o',
        '--output',
        type=pathlib.Path,
        help='path to write extended broadcast simulation JSON file ')

    # Argument parser for extending foundry broadcast
    parser_collate = subparsers.add_parser(
        'collate', help='collate signed extended broadcast simulation')
    parser_collate.add_argument(
        '-i',
        '--input',
        type=pathlib.Path,
        help='path to input signed extended broadcast simulation JSON')
    parser_collate.add_argument(
        '-o',
        '--output',
        type=pathlib.Path,
        help='path to write collated signed extended broadcast simulation JSON'
    )
    parser_collate.add_argument(
        '-f',
        '--flat-output',
        type=pathlib.Path,
        help='path to write flattened version of collated signed extended'
        ' broadcast simulation JSON')
    return parser


def main() -> None:
    argument_parser = _create_argument_parser()
    arguments = argument_parser.parse_args()
    try:
        if arguments.command == 'extend':
            _execute_command_extend(arguments)
        elif arguments.command == 'collate':
            _execute_command_collate(arguments)
        else:
            raise NotImplementedError
    except Exception as error:
        print("An error occurred:", type(error).__name__, "–", error)

        sys.exit(1)


if __name__ == "__main__":
    main()

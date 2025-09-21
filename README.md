# c2-client

A modular C2 client written purely in Bash, designed for testing and lab exercises in ethical hacking. The project focuses on simplicity, portability, and extensibility through modules (network, system, transfer, tor, shell, ...).

## Key Features

* Lightweight modules, registered via `register_function` (see `funcmgr.sh`).
* Fallbacks for minimal systems (`/proc`, `/sys`, `/dev/tcp`, or standard utilities if available).
* Unified and consistent UI for interacting with modules through the C2 client.
* Built for controlled lab use in ethical hacking scenarios.

## Project Structure

```

c2-client/
├─ modules.d/
│  ├─ network.sh      # network information and operations
│  ├─ system.sh       # system operations
│  ├─ transfer.sh     # upload/download
│  ├─ tor.sh          # tor socks proxy manipulation
│  ├─ *shell.sh       # core shell modules
│  └─ ...
├─ funcmgr.sh         # function/module manager
├─ modules.sh         # module management tool
├─ c2-client.sh       # main client entrypoint
├─ README.md
└─ CONTRIBUTORS.md

````

## Quick Start

1. Clone the repository:

```bash
git clone https://github.com/TWBerry/c2-client.git
cd c2-client
````

2. Explore available modules:

```bash
ls modules
```

3. Launch the client (inside your test lab):

```bash
./c2-client.sh <shell_module> <url> [shell_module_args]
```

> **Note:** This software is for testing and educational purposes in controlled environments only. Do not use it for unauthorized access or attacks.

## Module Types

There are two types of modules:

### 1. Shell Module (core)

Contains the main control functions of the C2 client. Must implement:

* `module_init()` — initialize and load global functions
* `module_main()` — main entrypoint for the shell module
* `show_module_help()` — display help and available commands
* `send_cmd()` — send commands to the target
* `module_description()` — module description

### 2. Internal Modules (extending functionality)

Each internal module has an auto-generated **module ID** (10-character alphanumeric string, mixed case) assigned at creation. Functions must be implemented with the ID prefix:

* `<ModuleID>_init()` — register functions via `register_function` and command-line parametrs via `register_cmdline_param`
* `<ModuleID>_main()` — main entrypoint for the module
* `<ModuleID>_help()` — display help for that module
* `<ModuleID>_description()` — module description

Functions are extended into the C2 client via:

```bash
register_function "command_name" "function_name" param_count "description"
```

Where:

* `command_name` = the command string used in the C2 shell
* `function_name` = Bash function name implemented in the module
* `param_count` = number of parameters expected(be aware -c <number> is counted as 2 one for -c and one for <number> )
* `Description` = short help text

## Command-Line Parameter Handling (`funcmgr.sh`)

The `funcmgr.sh` script provides helper functions for processing command-line arguments.

### Key Functions

* **`register_cmdline_param <param> <present_callback> <missing_callback>`**
  Register top-level CLI flags. If the parameter is present in `$@`, the `present_callback` function is called; otherwise, the `missing_callback` function is invoked.

* **`process_cmdline_params "$@"`**

  * Iterates over registered CLI parameters.
  * Calls the appropriate callbacks (`present` or `missing`).
  * Removes processed arguments and stores remaining unprocessed arguments in the global array `CMDLINE_REMAINING`.

```bash
# Example usage:
process_cmdline_params "$@"
echo "Remaining args: ${CMDLINE_REMAINING[*]}"
```

This system ensures modular commands and parameters are handled consistently and allows startup flags (e.g., `--no-tor`) to be processed automatically.

## Module Management (modules.sh)

Modules are managed through the `modules.sh` tool:

* `./modules.sh create <module_name>` — create a new module (auto-assigns a 10-char ID)
* `./modules.sh register <module_name>` — register the module for use in the C2 client
* `./modules.sh unregister <module_name>` — unregister and disable the module in the C2 client

## Example Usage

* Get a quick summary of network information:

```bash
net_summary
```

* Call a specific registered function:

```bash
detect_sandbox
```

## Contribution

Contributions are welcome — see `CONTRIBUTORS.md` for guidelines. Use feature branches and always test changes inside an isolated lab environment.

## Security & Ethical Notice

This project contains tools that can be misused. Always operate ethically and only in environments where you have explicit authorization (lab setups, test systems, or systems you own).

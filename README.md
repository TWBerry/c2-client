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
├─ scripts/
│  ├─ example.c2      # example c2 script
│  └─ ...
├─ modules.d/
│  ├─ network.sh      # network information and operations
│  ├─ system.sh       # system operations
│  ├─ transfer.sh     # upload/download
│  ├─ tor.sh          # tor socks proxy manipulation
│  ├─ debug.sh        # debug module
│  ├─ dir.sh          # dir movement implementation
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
* `param_count` = number of parameters expected(be aware -c number is counted as 2 one for -c and one for number )
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

## Command Wrappers

`register_cmd_wrapper`

Registers a command wrapper function that can transform or decorate commands before execution.

**Usage:**
```bash
register_cmd_wrapper <function_name> [priority]
````

* `<function_name>` – name of the wrapper function to register.
* `[priority]` – optional integer priority (default: `1000`). Wrappers are executed in ascending priority order. Lower numbers run earlier, higher numbers run later.

**Notes:**

* The higher the priority value, the closer to the end of the wrapper chain the function will be executed.
* Priorities `999` and `1000` are **reserved**:

  * `999` → `dir_wrapper` (virtual working directory manager).
  * `1000` → `debug_wrapper` (must always run last).
* All other wrappers should use values lower than `999`.

**Example:**

```bash
register_cmd_wrapper my_logger 100
```

This will insert `my_logger` into the wrapper chain with priority `100`, meaning it runs before `dir_wrapper` and `debug_wrapper`.

`unregister_cmd_wrapper()`
Unregisters the currently active command wrapper. Subsequent send_cmd() calls will execute commands normally without interception.

`cmd_wrapper <command>`
Executes the registered wrapper function if one exists. Otherwise, returns the original command unmodified. This function is automatically called inside the shell module send_cmd() function.

##Exit Functions

`register_exit_func <function_name>`
Registers a cleanup function to be executed automatically when the C2 shell exits (exit command or script termination). Useful for removing temporary files, disabling wrappers, or other cleanup operations.

`run_exit_funcs()`
Invokes all registered exit functions in order. This is automatically triggered by the trap set in funcmgr.sh:

## Module Management (modules.sh)

Modules are managed through the `modules.sh` tool:

* `./modules.sh create <module_name>` — create a new module (auto-assigns a 10-char ID)
* `./modules.sh register <module_name>` — register the module for use in the C2 client
* `./modules.sh unregister <module_name>` — unregister and disable the module in the C2 client

Jasně, můžeme do README doplnit sekci **Scripting / c2-scripts**, aby bylo jasné, že klient podporuje skripty a jak je používat. Tady je návrh, který můžeš vložit za stávající obsah:

---

## Scripting with c2-client (`c2-scripts`)

The C2 client supports **modular scripting**, allowing sequences of commands to be executed in an isolated and controlled environment. Scripts are written in a **Bash-like syntax**, but instead of running local commands, they call the **C2 client functions** to interact with remote targets.

### Key Features

* Runs in a **subshell with dangerous builtins disabled** (`exit`, `exec`, `eval`).
* Uses **C2 client functions** instead of direct shell commands:

  * `send_cmd` — send a command to the remote target
  * `emergency_upload` — transfer files if normal tools are missing
  * `print_std`, `print_err` — unified output functions
* Can include **loops, conditionals, and variables** like normal Bash.
* Designed to be **portable and safe** inside your lab environment — scripts cannot execute arbitrary local shell commands outside the client’s API.
* List of available c2-client specific functions is in `scripts/available_functions` file. This file is automatically updated by c2-client.

### Script Structure

A typical c2-script looks like this:

```bash
# Example script
print_std "[*] Running scan script..."
HOSTS=("10.0.0.1" "10.0.0.2")

for h in "${HOSTS[@]}"; do
    result=$(send_cmd "ping -c1 $h" || echo "FAIL")
    print_std "Host $h → $result"
done
```

### Running Scripts

1. Place the script in the `scripts/` directory.
2. Execute the script with the `run_script` from script module:

```c2
run_script ./scripts/my_scan.c2 param1 param2...
```

3. All output is **captured through the client**, and errors are handled via `print_err` or internal logging.
4. Up to ten parameters is supported.

### Notes

* Scripts are executed **in order**, and each `send_cmd` waits for completion by default.
* Dangerous builtins are blocked to prevent accidental termination of the client.
* Scripts can be **reused across labs**, making testing and automation straightforward.
* You can combine scripts with modules, e.g., network discovery, file transfer, or shell modules.

## Contribution

Contributions are welcome — see `CONTRIBUTORS.md` for guidelines. Use feature branches and always test changes inside an isolated lab environment.

## Security & Ethical Notice

This project contains tools that can be misused. Always operate ethically and only in environments where you have explicit authorization (lab setups, test systems, or systems you own).

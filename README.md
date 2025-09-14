# c2-client

A modular, educational Command & Control client written in Bash.  
Designed for penetration testing labs and security research.

⚠️ **Disclaimer**  
This project is for **educational purposes only**.  
Do not use it against systems without explicit authorization.

---

## Features

- Modular design — each module implements its own `send_cmd` logic.
- Support for multiple bootstrap helpers (base64, PHP, Python, etc.).
- Emergency file upload mechanism for environments with minimal tooling.
- Simple encryption and obfuscation examples.

---

## Quickstart

    git clone https://github.com/yourusername/c2-client.git
    cd c2-client
    chmod +x client.sh
    ./client.sh lir_shell "http://target/path"

## Modules

Modules live in the modules/ directory.
Each module must implement:

    module_init()
    module_main()
    send_cmd()
    module_description()
    show_module_help()

## Example

Run the PHP log injection module against a target:

    ./client.sh lir_shell.sh "http://target/upload.php"

## Contributing

See CONTRIBUTING.md.

#$License

MIT License

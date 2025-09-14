# Contributing Guidelines

Thank you for your interest in contributing to this project!  
This client is designed as an educational tool for penetration testers and security students.  
**Never use it against systems without explicit permission.**

---

## Getting Started

1. **Fork the repository** on GitHub.
2. **Clone your fork** locally:

    git clone git@github.com:yourusername/c2-client.git
    cd c2-client

3. Create a feature branch:

    git checkout -b feat/my-feature


4. Make your changes and add tests or examples if possible.

5. Commit your changes with a clear message:

    git commit -m "Add new module for PHP payload injection"

6. Push your branch:

    git push origin feat/my-feature

7. Open a Pull Request against the main branch.

**Code Style**

Shell scripts must pass shellcheck without critical warnings.
Use shfmt -i 2 -ci for formatting.
Each module should implement the required functions:

    module_init()
    module_main()
    send_cmd()
    module_description()
    show_module_help()

**Pull Requests**

Ensure your PR description clearly explains what, why, and how.
If your PR introduces a new module, provide:
A short description in README.md.
Usage example in examples/.
All PRs must pass CI before merging.

**Security Notice**

This repository is for educational and authorized security testing only.
Do not submit code that attempts to hide malicious functionality.
All contributions must include comments explaining purpose and usage.

**License**

By contributing, you agree that your code will be licensed under the MIT License.

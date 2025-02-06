# BlackArchCat Installation Script

This script automates the installation of Pentesting tools and other related utilities on a Linux system. It manages checkpoints to ensure that the installation can be resumed from the last completed step in case of interruptions.

## Table of Contents
- [Usage](#usage)
- [Checkpoints](#checkpoints)
- [Requirements](#requirements)
- [License](#license)

## Usage
To run the script, execute the following command in your terminal:
```bash
chmod +x ./blackarchcat.sh
./blackarchcat.sh
```

## Checkpoints
The script defines a series of [checkpoints](https://github.com/ThomasMTT/checkpoint-sh) that correspond to different installation steps:
1. `install_blackarch` - Installs BlackArch.
2. `install_systemwide_tools` - Installs system-wide tools and packages.
3. `install_local_tools` - Installs local tools.
4. `install_docker_tools` - Installs Docker-based tools.
5. `download_wordlists` - Downloads wordlists for security testing.
6. `cleanup` - Cleans up temporary files.

The script will resume from the last completed checkpoint if it is interrupted.

## Requirements
- **Dependencies**: The script requires the following programs to be installed:
  - `pipx`
  - `go`
  - `jq`
  - `gem`
  - `git`
  
  The script will attempt to install these dependencies using `pacman` if they are not found.

## License
This project is licensed under the Apache v2 License. See the [LICENSE](LICENSE) file for more details.

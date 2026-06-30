#!/usr/bin/env python3
"""
Configr File Module Demo Script
"""

import json
import os
from pathlib import Path


def main():
    print("Configr File Module Demo")
    print("=" * 30)
    
    # Read the JSON config
    config_path = Path("config.json")
    if config_path.exists():
        with open(config_path) as f:
            config = json.load(f)
        
        print(f"App Name: {config['name']}")
        print(f"Version: {config['version']}")
        print(f"Theme: {config['settings']['theme']}")
        print(f"Auto Save: {config['settings']['auto_save']}")
        
        print("\nFeatures:")
        for feature in config['features']:
            print(f"  - {feature}")
    else:
        print("Config file not found!")


if __name__ == "__main__":
    main()
#!/usr/bin/python3

import json


with open("inventory.json") as f:
    data = json.load(f)
    print(json.dumps(data))

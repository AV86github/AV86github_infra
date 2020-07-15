#!/usr/bin/python3

from subprocess import Popen, PIPE
import json


class RedditInventory():
    """
        Dynamic inventory for reddit app in google cload

    """
    def __init__(self):
        process = Popen(["gcloud",
                         "compute",
                         "instances",
                         "list",
                         "--format=value(name, tags.items, EXTERNAL_IP)"],
                        stdout=PIPE,
                        stderr=PIPE,
                        universal_newlines=True
                        )
        result, _ = process.communicate()
        self._vm_list = list(vm_inst.split("\t") for vm_inst in result.split("\n") if len(vm_inst) > 2)

        # generate inventory
        self.generate_inventory()

    def _get_instances_by_tag(self, tag_name):
        return [vm_inst[0] for vm_inst in self._vm_list if tag_name in vm_inst[1]]

    def _add_all_meta(self):
        meta = {}
        for inst in self._vm_list:
            if inst[0] not in meta.keys():
                meta.update({inst[0]: {"ansible_host": inst[2]}})
        return meta

    def generate_inventory(self):
        inventory = {
            "_meta": {
                "hostvars": self._add_all_meta()
            },
            "all": {
                "children": [
                    "app",
                    "db"
                ]
            },
            "app": {
                "hosts": self._get_instances_by_tag("reddit-app")
            },
            "db": {
                "hosts": self._get_instances_by_tag("reddit-db")
            }
        }
        print(json.dumps(inventory))


if __name__ == "__main__":
    RedditInventory()

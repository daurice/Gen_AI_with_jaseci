import networkx as nx
from typing import Dict, List
import os

class CodeContextGraph:
    def __init__(self):
        self.G = nx.DiGraph()

    def add_node(self, filepath: str, name: str, type: str, line: int):
        node_id = f"{filepath}:{name}"
        self.G.add_node(node_id, filepath=filepath, name=name, type=type, line=line)

    def add_call(self, caller: str, callee: str):
        self.G.add_edge(caller, callee, relationship="calls")

    def add_inherits(self, child: str, parent: str):
        self.G.add_edge(child, parent, relationship="inherits")

    def query_callers(self, func_name: str) -> List[str]:
        return [n for n, d in self.G.in_edges(func_name) if d.get("relationship") == "calls"]

    def query_callees(self, func_name: str) -> List[str]:
        return [n for n, d in self.G.out_edges(func_name) if d.get("relationship") == "calls"]

    def to_dict(self):
        return nx.node_link_data(self.G)
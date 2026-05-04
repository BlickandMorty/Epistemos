"""
resonance_formal_impl.py
Formal implementation of the Resonance Model as a retrieval architecture.
No metaphors — only data structures, algorithms, and complexity.
"""

import math
import random
from collections import Counter
from typing import Dict, Set, Tuple, List, Any

# Optional: networkx for graph operations
try:
    import networkx as nx
except ImportError:
    raise ImportError("Install networkx: pip install networkx")


# =============================================================================
# 1. RESONANCE GRAPH
# =============================================================================

class ResonanceGraph:
    """
    A labeled, weighted, time-decaying knowledge graph.
    
    Data structure:
        G = (V, E, L, w, tau)
        V : set of nodes (puzzle pieces)
        E : set of edges (lock-and-key alignments)
        L : edge labels (relation types)
        w : edge weights
        tau : global forgetting time constant
    """

    def __init__(self, tau: float = 10.0):
        self.G = nx.Graph()
        self.tau = tau
        self.last_access: Dict[Tuple[Any, Any], float] = {}
        self.ternary_state: Dict[Any, int] = {}  # +1, 0, -1

    def add_piece(self, node: Any, state: int = 0):
        """Add a puzzle piece with a ternary state."""
        self.G.add_node(node)
        self.ternary_state[node] = state

    def add_edge(self, u: Any, v: Any, label: str, weight: float = 1.0):
        """Add an edge with a label and weight."""
        self.G.add_edge(u, v, label=label, weight=weight)
        self.last_access[(u, v)] = 0.0
        self.last_access[(v, u)] = 0.0  # undirected

    def access_edge(self, u: Any, v: Any, now: float):
        """Mark an edge as accessed at time `now`, resetting its erosion clock."""
        if self.G.has_edge(u, v):
            self.last_access[(u, v)] = now
            self.last_access[(v, u)] = now

    def effective_weight(self, u: Any, v: Any, now: float) -> float:
        """
        Erosion-adjusted weight: w_eff = w * exp(-(now - last_access) / tau)
        Complexity: O(1)
        """
        if not self.G.has_edge(u, v):
            return 0.0
        w = self.G[u][v].get("weight", 1.0)
        t0 = self.last_access.get((u, v), 0.0)
        return w * math.exp(-(now - t0) / self.tau)


# =============================================================================
# 2. RESONANCE MEASURES (CLARITY & COLOR)
# =============================================================================

class ResonanceMeasures:
    """
    Computes clarity, color, and the composite resonance score.
    """

    @staticmethod
    def clarity(graph: ResonanceGraph, node: Any) -> float:
        """
        Clarity = degree of the node (quantity of connections).
        Complexity: O(1) if degree cached, else O(deg(v)).
        """
        return float(graph.G.degree(node))

    @staticmethod
    def clustering_coefficient(graph: ResonanceGraph, node: Any) -> float:
        """
        Local clustering coefficient C_v = 2*e_v / (k_v * (k_v - 1))
        Complexity: O(deg(v)^2) in the worst case (counting neighbor edges).
        """
        return float(nx.clustering(graph.G, node))

    @staticmethod
    def color_entropy(graph: ResonanceGraph, node: Any) -> float:
        """
        Color = Shannon entropy of edge-label distribution incident to node.
        H(v) = -sum_{l} p_l log2(p_l)
        Complexity: O(deg(v))
        """
        if node not in graph.G:
            return 0.0
        labels = [d["label"] for _, _, d in graph.G.edges(node, data=True)]
        if not labels:
            return 0.0
        counts = Counter(labels)
        k = len(labels)
        h = 0.0
        for count in counts.values():
            p = count / k
            h -= p * math.log2(p)
        return h

    @staticmethod
    def eigenvector_centrality(graph: ResonanceGraph) -> Dict[Any, float]:
        """
        Eigenvector centrality via power iteration (networkx implementation).
        Complexity: O(|E| * T) where T is iterations to convergence.
        """
        return nx.eigenvector_centrality(graph.G, weight="weight", max_iter=1000)

    @staticmethod
    def resonance_score(graph: ResonanceGraph, node: Any, now: float,
                        use_eigenvector: bool = True) -> float:
        """
        R(v) = centrality(v) * (1 - C_v) * w_eff
        
        If use_eigenvector=True, centrality = eigenvector centrality.
        Otherwise, centrality = degree (clarity).
        
        Complexity:
            - With precomputed eigenvector: O(deg(v)^2)
            - Without precomputation:   O(|E|*T + deg(v)^2)
        """
        k = graph.G.degree(node)
        if k < 2:
            return 0.0

        if use_eigenvector:
            # In practice, cache this globally
            cent = ResonanceMeasures.eigenvector_centrality(graph)
            clarity = cent.get(node, 0.0)
        else:
            clarity = float(k)

        C_v = ResonanceMeasures.clustering_coefficient(graph, node)
        color = 1.0 - C_v

        # Use average effective weight of incident edges
        eff_weights = [
            graph.effective_weight(node, nbr, now)
            for nbr in graph.G.neighbors(node)
        ]
        w_avg = sum(eff_weights) / len(eff_weights) if eff_weights else 0.0

        return clarity * color * w_avg


# =============================================================================
# 3. TERNARY LOGIC & ATTENTION MASKING
# =============================================================================

class TernaryLogic:
    """
    Kleene's strong three-valued logic K3 mapped to {+1, 0, -1}.
    """
    T = +1   # True / Fits
    U = 0    # Undefined / Waiting
    F = -1   # False / Does not fit

    @staticmethod
    def and_(a: int, b: int) -> int:
        """Kleene AND truth table."""
        table = {
            (+1, +1): +1, (+1, 0): 0, (+1, -1): -1,
            (0, +1): 0,  (0, 0): 0,  (0, -1): -1,
            (-1, +1): -1, (-1, 0): -1, (-1, -1): -1,
        }
        return table.get((a, b), 0)

    @staticmethod
    def or_(a: int, b: int) -> int:
        """Kleene OR truth table."""
        table = {
            (+1, +1): +1, (+1, 0): +1, (+1, -1): +1,
            (0, +1): +1,  (0, 0): 0,  (0, -1): 0,
            (-1, +1): +1, (-1, 0): 0, (-1, -1): -1,
        }
        return table.get((a, b), 0)

    @staticmethod
    def not_(a: int) -> int:
        """Kleene NOT."""
        return -a if a != 0 else 0

    @staticmethod
    def to_attention_mask(a: int) -> float:
        """
        Map ternary state to attention mask:
            +1 -> 1.0  (attend)
             0 -> 0.0  (mask out)
            -1 -> -1.0 (inhibit)
        """
        return float(a)


# =============================================================================
# 4. EROSION (FORGETTING) MECHANISMS
# =============================================================================

class Erosion:
    """
    Implements exponential decay and EWC-style regularization.
    """

    @staticmethod
    def exponential_decay(weight: float, t: float, tau: float) -> float:
        """w_eff = w * exp(-t / tau). Complexity: O(1)."""
        return weight * math.exp(-t / tau)

    @staticmethod
    def ewc_penalty(theta: float, theta_star: float, fisher: float, lam: float = 1.0) -> float:
        """
        EWC quadratic penalty: (lambda/2) * F * (theta - theta*)^2.
        Complexity: O(1).
        """
        return (lam / 2.0) * fisher * (theta - theta_star) ** 2


# =============================================================================
# 5. FIVE DIRECTIONS AS GRAPH OPERATIONS
# =============================================================================

class Directions:
    """
    Formal operations on a knowledge graph.
    """

    @staticmethod
    def upward(graph: ResonanceGraph, node: Any, relation: str = "is_a") -> Set[Any]:
        """
        Upward = transitive closure along a given relation (e.g., is_a).
        Returns all ancestors.
        Complexity: O(|V| + |E|) per BFS/DFS.
        """
        # Build a directed view for the specific relation
        DG = nx.DiGraph()
        for u, v, d in graph.G.edges(data=True):
            if d.get("label") == relation:
                DG.add_edge(u, v)
        if node not in DG:
            return set()
        return set(nx.descendants(DG, node)) | {node}

    @staticmethod
    def downward(graph: ResonanceGraph, node: Any, relation: str = "is_a") -> Set[Any]:
        """
        Downward = all descendants along the relation (inverse of upward).
        Returns the abstraction class below node.
        Complexity: O(|V| + |E|).
        """
        DG = nx.DiGraph()
        for u, v, d in graph.G.edges(data=True):
            if d.get("label") == relation:
                DG.add_edge(u, v)
        if node not in DG:
            return set()
        return set(nx.ancestors(DG, node)) | {node}

    @staticmethod
    def sideways(graph: ResonanceGraph, node: Any, relation: str = "is_a") -> Set[Any]:
        """
        Sideways = siblings: nodes sharing a parent via the same relation.
        Complexity: O(deg_in(node) + sum(deg_out(parents))).
        """
        DG = nx.DiGraph()
        for u, v, d in graph.G.edges(data=True):
            if d.get("label") == relation:
                DG.add_edge(u, v)
        parents = set(DG.predecessors(node))
        siblings = set()
        for p in parents:
            for child in DG.successors(p):
                if child != node:
                    siblings.add(child)
        return siblings

    @staticmethod
    def inward(graph: ResonanceGraph, node: Any) -> nx.Graph:
        """
        Inward = ego-network (node + neighbors, with induced edges).
        Complexity: O(deg(node)^2).
        """
        neighbors = set(graph.G.neighbors(node))
        neighbors.add(node)
        return graph.G.subgraph(neighbors).copy()

    @staticmethod
    def on_itself(graph: ResonanceGraph, node: Any) -> None:
        """
        On itself = add a self-loop edge labeled 'self'.
        Complexity: O(1).
        """
        graph.G.add_edge(node, node, label="self", weight=1.0)


# =============================================================================
# 6. "LOOKING" AS ACTIVE INFERENCE / TDD TRAVERSAL
# =============================================================================

class LookEngine:
    """
    Simulates the 'looking' process:
        1. Generate 3 hypotheses (outcomes).
        2. Binary compute prediction error for each.
        3. Select hypothesis minimizing free energy.
    """

    @staticmethod
    def predict(hypothesis: Any, context: Dict) -> Any:
        """Stub: generate a predicted observation from a hypothesis."""
        # In a real system, this is a generative model forward pass.
        return hash(hypothesis) % 100  # deterministic stub

    @staticmethod
    def free_energy(prediction: Any, observation: Any) -> float:
        """
        Free energy = prediction error + KL term (simplified here to MSE).
        Complexity: O(dim(observation)).
        """
        return float(abs(prediction - observation))

    @classmethod
    def look(cls, observation: Any, hypotheses: List[Any]) -> Tuple[Any, float]:
        """
        Evaluate each of 3 (or N) hypotheses and return the best.
        Complexity: O(|H| * f) where f = cost of prediction + error.
        """
        best_hyp = None
        min_fe = float("inf")
        for h in hypotheses:
            pred = cls.predict(h, {})
            fe = cls.free_energy(pred, observation)
            if fe < min_fe:
                min_fe = fe
                best_hyp = h
        return best_hyp, min_fe


# =============================================================================
# 7. DEMONSTRATION
# =============================================================================

if __name__ == "__main__":
    # Build a tiny resonance graph
    rg = ResonanceGraph(tau=5.0)
    for i in range(1, 8):
        rg.add_piece(i, state=random.choice([+1, 0, -1]))

    edges = [
        (1, 2, "causes", 1.0),
        (1, 3, "causes", 0.8),
        (2, 3, "similar", 0.5),
        (2, 4, "is_a", 1.0),
        (3, 5, "is_a", 1.0),
        (4, 6, "is_a", 1.0),
        (5, 6, "similar", 0.6),
        (5, 7, "causes", 0.9),
    ]
    for u, v, label, w in edges:
        rg.add_edge(u, v, label, w)

    now = 10.0
    # Access some edges to reset their clocks
    rg.access_edge(1, 2, now)
    rg.access_edge(1, 3, now)

    # Compute resonance scores
    print("=== Resonance Scores ===")
    for node in rg.G.nodes():
        r = ResonanceMeasures.resonance_score(rg, node, now, use_eigenvector=False)
        c = ResonanceMeasures.color_entropy(rg, node)
        print(f"Node {node}: clarity={rg.G.degree(node)}, color={c:.3f}, R={r:.3f}")

    # Ternary logic demo
    print("\n=== Ternary Logic AND ===")
    for a in [+1, 0, -1]:
        for b in [+1, 0, -1]:
            print(f"{a} AND {b} = {TernaryLogic.and_(a, b)}")

    # Directions demo
    print("\n=== Directions from Node 1 ===")
    print("Upward (is_a):", Directions.upward(rg, 1, "is_a"))
    print("Downward (is_a):", Directions.downward(rg, 1, "is_a"))
    print("Sideways (is_a):", Directions.sideways(rg, 4, "is_a"))
    print("Inward (node 2): nodes =", list(Directions.inward(rg, 2).nodes()))
    Directions.on_itself(rg, 1)
    print("On itself (self-loop added):", rg.G.has_edge(1, 1))

    # Look demo
    print("\n=== Looking (3 hypotheses) ===")
    best, fe = LookEngine.look(observation=42, hypotheses=["h1", "h2", "h3"])
    print(f"Best hypothesis: {best}, Free energy: {fe:.3f}")

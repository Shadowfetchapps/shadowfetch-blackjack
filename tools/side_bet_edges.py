#!/usr/bin/env python3
"""Exact house edges for the Shadowfetch Blackjack side bets.

Perfect Pairs (25/12/6) and 21+3 (100/40/30/10/5) are evaluated by exact
combinatorics over an n-deck shoe (no simulation). The results are the
BJSideBets.HOUSE_EDGE table in scripts/engine/bj_side_bets.gd.

    python3 tools/side_bet_edges.py
"""
from collections import Counter
from fractions import Fraction

PP_PAYS = {"perfect": 25, "colored": 12, "mixed": 6}
T3_PAYS = {"suited_trips": 100, "straight_flush": 40, "three_kind": 30, "straight": 10, "flush": 5}


def perfect_pairs_edge(decks: int) -> Fraction:
    rest = 52 * decks - 1
    p = {"perfect": Fraction(decks - 1, rest), "colored": Fraction(decks, rest), "mixed": Fraction(2 * decks, rest)}
    ev = sum(PP_PAYS[k] * p[k] for k in p) - (1 - sum(p.values()))
    return -ev


def classify(a, b, c) -> str:
    flush = a[1] == b[1] == c[1]
    trips = a[0] == b[0] == c[0]
    ranks = sorted([a[0], b[0], c[0]])
    straight = len(set(ranks)) == 3 and (ranks[2] - ranks[0] == 2 or ranks == [1, 12, 13])
    if trips and flush:
        return "suited_trips"
    if straight and flush:
        return "straight_flush"
    if trips:
        return "three_kind"
    if straight:
        return "straight"
    if flush:
        return "flush"
    return ""


def twenty_one_three_edge(decks: int) -> Fraction:
    cards = [(r, s) for r in range(1, 14) for s in range(4)]
    counts = Counter()
    for i, a in enumerate(cards):
        for j, b in enumerate(cards):
            for k, c in enumerate(cards):
                nb = decks - (j == i)
                nc = decks - (k == i) - (k == j)
                if nb > 0 and nc > 0:
                    counts[classify(a, b, c)] += decks * nb * nc
    total = sum(counts.values())
    ev = sum(Fraction(n * T3_PAYS.get(k, -1)) for k, n in counts.items()) / total
    return -ev


if __name__ == "__main__":
    for d in (1, 2, 4, 6, 8):
        print(f"{d} deck(s): Perfect Pairs {float(perfect_pairs_edge(d)) * 100:6.2f}%   "
              f"21+3 {float(twenty_one_three_edge(d)) * 100:6.2f}%")

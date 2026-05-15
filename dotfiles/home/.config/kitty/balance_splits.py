#!/usr/bin/env python


def main(args):
    pass


def _count_same_axis(node, horizontal):
    from kitty.layout.splits import Pair

    if not isinstance(node, Pair):
        return 1
    if node.horizontal == horizontal:
        return _count_same_axis(node.one, horizontal) + _count_same_axis(node.two, horizontal)
    return 1


def _equalize(pair):
    from kitty.layout.splits import Pair

    left = _count_same_axis(pair.one, pair.horizontal)
    right = _count_same_axis(pair.two, pair.horizontal)
    pair.bias = left / (left + right)

    if isinstance(pair.one, Pair):
        _equalize(pair.one)
    if isinstance(pair.two, Pair):
        _equalize(pair.two)


def handle_result(args, answer, target_window_id, boss):
    tab = boss.active_tab
    if tab is None:
        return
    if tab.current_layout.name != "splits":
        return
    root = tab.current_layout.pairs_root
    _equalize(root)
    tab.relayout()


handle_result.no_ui = True
